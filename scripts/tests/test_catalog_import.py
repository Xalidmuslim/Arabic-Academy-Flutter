import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from scripts import catalog_import


def sample():
    ids = [f"00000000-0000-4000-8000-{i:012d}" for i in range(1, 8)]
    locator = {"book_id": ids[3], "start": 2, "end": 3}
    return {
        "schema_version": 1, "catalog_id": ids[0], "edition": "Owner edition 2025",
        "license": {"status": "granted", "reference": "owner-license-1",
                    "holder": "Owner", "permission_reference": "rights/document-1",
                    "permitted_uses": ["digital_learning"]},
        "provenance": {"publisher": "Publisher", "source_reference": "owner-manifest",
                       "verified_by": "Owner editor", "verified_at": "2026-10-12"},
        "counts": {"courses": 1, "levels": 1, "books": 1,
                   "units": 1, "lessons": 1, "blocks": 1},
        "courses": [{"id": ids[1], "title": "Course", "slug": "owner-course",
                     "access_tier": "paid", "status": "draft", "levels": [
            {"id": ids[2], "course_id": ids[1], "title": "Level", "position": 0,
             "books": [{"id": ids[3], "level_id": ids[2], "title": "Book",
                        "position": 0, "edition": "Owner edition 2025",
                        "license_reference": "owner-license-1", "page_count": 90,
                        "source_reference": "publisher/book.pdf", "source_sha256": "ab" * 32,
                        "units": [{"id": ids[4], "book_id": ids[3], "title": "Unit",
                                   "position": 0, "page_locator": locator,
                                   "lessons": [{"id": ids[5], "unit_id": ids[4],
                                                "title": "Lesson", "position": 0,
                                                "status": "draft", "page_locator": locator,
                                                "blocks": [{"id": ids[6], "lesson_id": ids[5],
                                                            "step": "grammar", "kind": "text",
                                                            "position": 0, "page_locator": locator,
                                                            "body": {"ar": "كِتَابٌ", "text": "Owner text"}}]}]}]}]}
        ]}],
    }


def book(data):
    return data["courses"][0]["levels"][0]["books"][0]


def lesson(data):
    return book(data)["units"][0]["lessons"][0]


class CatalogTests(unittest.TestCase):
    def test_complete_manifest_preserves_ids_vowels_and_provenance(self):
        data = sample()
        original = copy.deepcopy(data)
        plan = catalog_import.build_plan(data)
        self.assertEqual(data, original)
        self.assertEqual(plan["counts"], data["counts"])
        self.assertEqual(plan["rows"]["blocks"][0]["id"], lesson(data)["blocks"][0]["id"])
        self.assertEqual(plan["rows"]["blocks"][0]["body"]["ar"], "كِتَابٌ")
        self.assertEqual(plan["manifest"], data)
        self.assertEqual(plan["status"], "draft")
        self.assertEqual(plan['rows']['lessons'][0]['source_locator']['page_start'], 2)
        self.assertEqual(plan['rows']['books'][0]['source_locator']['pdf_sha256'], 'ab' * 32)

    def test_missing_or_ungranted_license_never_imports(self):
        for value in [None, {}, {"status": "not_provided"},
                      {**sample()["license"], "permitted_uses": ["personal_reading"]},
                      {**sample()["license"], "permission_reference": "TBD"}]:
            with self.subTest(value=value):
                data = sample()
                data["license"] = value
                with self.assertRaises(catalog_import.ValidationError):
                    catalog_import.build_plan(data)

    def test_invalid_pages_types_ranges_and_book_references(self):
        for patch in [{"start": 0}, {"start": True}, {"start": 4, "end": 3},
                      {"end": 91}, {"start": "2"}, {"book_id": sample()["catalog_id"]}]:
            with self.subTest(patch=patch):
                data = sample()
                lesson(data)["page_locator"] = {**lesson(data)["page_locator"], **patch}
                with self.assertRaises(catalog_import.ValidationError):
                    catalog_import.build_plan(data)

    def test_child_pages_cannot_escape_parent_range(self):
        data = sample()
        lesson(data)["blocks"][0]["page_locator"] = {
            **lesson(data)["page_locator"], "start": 1,
        }
        with self.assertRaises(catalog_import.ValidationError):
            catalog_import.build_plan(data)

    def test_duplicate_ids_and_foreign_parents_are_rejected(self):
        for mutate in [
            lambda d: lesson(d).__setitem__("id", book(d)["id"]),
            lambda d: lesson(d).__setitem__("unit_id", d["catalog_id"]),
            lambda d: lesson(d)["blocks"][0].__setitem__("id", "not-a-uuid"),
        ]:
            data = sample()
            mutate(data)
            with self.assertRaises(catalog_import.ValidationError):
                catalog_import.build_plan(data)

    def test_duplicate_sibling_positions_and_wrong_counts_fail(self):
        data = sample()
        extra = copy.deepcopy(lesson(data)["blocks"][0])
        extra["id"] = "00000000-0000-4000-8000-000000000099"
        lesson(data)["blocks"].append(extra)
        with self.assertRaises(catalog_import.ValidationError):
            catalog_import.build_plan(data)
        data = sample()
        data["counts"]["books"] = 2
        with self.assertRaises(catalog_import.ValidationError):
            catalog_import.build_plan(data)

    def test_incomplete_hierarchy_and_missing_edition_fail(self):
        for mutate in [lambda d: book(d).__setitem__("units", []),
                       lambda d: d.pop("edition"),
                       lambda d: book(d).__setitem__("edition", "different edition")]:
            data = sample()
            mutate(data)
            with self.assertRaises(catalog_import.ValidationError):
                catalog_import.build_plan(data)

    def test_reserved_metadata_and_automatic_publishing_fail(self):
        for mutate in [lambda d: lesson(d).__setitem__("status", "published"),
                       lambda d: lesson(d)["blocks"][0]["body"].__setitem__("page_locator", {})]:
            data = sample()
            mutate(data)
            with self.assertRaises(catalog_import.ValidationError):
                catalog_import.build_plan(data)

    def test_enum_fields_reject_wrong_json_types_without_crashing(self):
        for value in [[], {}, True, 1, None]:
            for field in ['step', 'kind', 'access_tier']:
                with self.subTest(field=field, value=value):
                    data = sample()
                    node = data['courses'][0] if field == 'access_tier' else lesson(data)['blocks'][0]
                    node[field] = value
                    with self.assertRaises(catalog_import.ValidationError):
                        catalog_import.build_plan(data)

    def test_sql_is_transactional_insert_only_and_quotes_content(self):
        data = sample()
        lesson(data)["title"] = "Owner's lesson'); DROP TABLE public.courses; --"
        sql = catalog_import.render_sql(catalog_import.build_plan(data))
        self.assertTrue(sql.startswith("BEGIN;"))
        self.assertTrue(sql.rstrip().endswith("COMMIT;"))
        self.assertIn("Owner''s lesson''); DROP", sql)
        self.assertNotIn("ON CONFLICT", sql)
        self.assertNotIn("DISABLE ROW LEVEL", sql)
        self.assertIn("INSERT INTO public.lesson_blocks", sql)

    def test_duplicate_json_keys_and_nonfinite_numbers_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "manifest.json"
            for text in ['{"courses": [], "courses": []}', '{"value": NaN}']:
                source.write_text(text)
                with self.assertRaises(catalog_import.ValidationError):
                    catalog_import.load_manifest(source)

    def test_cli_validates_everything_before_creating_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / "manifest.json", Path(directory) / "plan.sql"
            data = sample()
            lesson(data)["blocks"][0]["page_locator"] = {"start": -1}
            source.write_text(json.dumps(data))
            completed = subprocess.run([sys.executable, "scripts/catalog_import.py", str(source),
                                        "--format", "sql", "--output", str(output)], capture_output=True)
            self.assertNotEqual(completed.returncode, 0)
            self.assertFalse(output.exists())

    def test_rpc_requires_https_credentials_and_verified_ack(self):
        plan = catalog_import.build_plan(sample())
        with mock.patch.dict("os.environ", {}, clear=True):
            with self.assertRaises(catalog_import.ValidationError):
                catalog_import.apply_rpc(plan)
        with mock.patch.dict("os.environ", {"CATALOG_SUPABASE_URL": "http://example.com",
                                           "CATALOG_API_KEY": "secret", "CATALOG_ACCESS_TOKEN": "token"}):
            with self.assertRaises(catalog_import.ValidationError):
                catalog_import.apply_rpc(plan)
        with self.assertRaises(catalog_import.ValidationError):
            catalog_import.validate_receipt(plan, {"status": "success"})
        receipt = {key: plan[key] for key in ["catalog_id", "counts", "manifest_sha256", "status"]}
        catalog_import.validate_receipt(plan, receipt)

    def test_rpc_bad_headers_and_server_json_do_not_expose_values(self):
        plan = catalog_import.build_plan(sample())
        environment = {'CATALOG_SUPABASE_URL': 'https://example.com',
                       'CATALOG_API_KEY': 'test-key', 'CATALOG_ACCESS_TOKEN': 'private-test-value\n'}
        with mock.patch.dict('os.environ', environment):
            with self.assertRaises(catalog_import.ValidationError) as error:
                catalog_import.apply_rpc(plan)
            self.assertNotIn('private-test-value', str(error.exception))
        environment['CATALOG_ACCESS_TOKEN'] = 'valid-test-token'
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = b'{"private-server-value":1,"private-server-value":2}'
        with mock.patch.dict('os.environ', environment), mock.patch.object(catalog_import.request, 'build_opener') as opener:
            opener.return_value.open.return_value = response
            with self.assertRaises(catalog_import.ValidationError) as error:
                catalog_import.apply_rpc(plan)
            self.assertNotIn('private-server-value', str(error.exception))

    def test_rpc_redirects_and_boolean_counts_cannot_verify_an_import(self):
        plan = catalog_import.build_plan(sample())
        receipt = {key: plan[key] for key in ["catalog_id", "counts", "manifest_sha256", "status"]}
        receipt["counts"] = {key: True for key in plan["counts"]}
        with self.assertRaises(catalog_import.ValidationError):
            catalog_import.validate_receipt(plan, receipt)
        with self.assertRaises(catalog_import.ValidationError):
            catalog_import._NoRedirect().redirect_request(None, None, 302, 'redirect', {}, 'https://different.example')


if __name__ == "__main__":
    unittest.main()
