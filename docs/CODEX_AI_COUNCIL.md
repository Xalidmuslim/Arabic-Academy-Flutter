# Codex Cloud + AI-Council — no separate OpenAI API

This is a **manual handoff workflow**. A ChatGPT subscription can provide
Codex usage within plan limits, but these repository files **cannot start**
Codex tasks, create a cloud environment, or grant GitHub permissions.

## First pilot: Issue #48

- Public project: `Xalidmuslim/Arabic-Academy-Flutter`.
- Issue: https://github.com/Xalidmuslim/Arabic-Academy-Flutter/issues/48
- Verified original baseline commit: `d6728363bf7969bf76a95457e2c5c12b29fbe057`.
- Authorized pilot file scope: `test/widget_test.dart`, `test/content_test.dart`.
- Do not change `lib/`, `assets/`, translations, Arabic harakat, books,
  `pubspec.yaml`, `android/` or `.github/` in **this** pilot.
- If the current target main has diverged from the recorded baseline, stop,
  inspect differences, and request a newly approved base rather than rewinding
  existing fixes or replacing more recent work.
- Existing application test commands:
  `flutter create --project-name arabic_academy --platforms android,ios .`
  (for temporary missing platform scaffolding on CI),
  `flutter pub get`, `flutter analyze --no-fatal-infos`,
  `flutter test`.

## Operator steps

1. On desktop/web sign in at https://chatgpt.com/codex, create/publish a
   Codex Cloud environment, and connect the GitHub account and this repo.
   Confirm the environment actually has access; the normal ChatGPT GitHub
   connector alone does not imply Codex push rights.
2. In AI-Council, use
   `agent_inputs/codex_cloud_pilot_48.json` and
   `python3 tools/codex_handoff.py` to generate
   `handoff_reports/codex/programmer.md` and
   `handoff_reports/codex/reviewer.md`. Alternatively read the same scoped
   contract directly. This preparation uses **zero model calls and no API**.
3. Open a Codex Cloud task on *this target repository* with the
   `programmer.md` prompt. Codex reads this repo's `AGENTS.md`.
   Programmer inspects actual sources, writes tests, runs checks, and creates
   a **draft** PR only if it has an authorized push capability.
4. Review the proposed diff and the pull-request CI run
   `AI-Council Flutter PR tests (no API)`. A successful CI result does not
   prove correctness or absence of regressions.
5. Open a **separate new Codex task** with the `reviewer.md` prompt and
   the exact draft PR URL and head SHA. This second task independently reviews
   the diff and test evidence. It must not edit code or merge.
6. A human decides whether to request fixes, accept or close the draft PR.
   There is no automatic merge, no API-key expense, no autonomous 24/7 loop.

## Real evidence policy

Every PR must state actual branch, base/head SHA, full changed-path list,
commands attempted, CI URLs with observed outcome, source-content impacts,
current limitations and untested cases. Write `NOT_RUN` when tests were not
run, and `NEEDS_CHECK` when sources/CI are missing. Build artifacts and device
performance numbers require genuine build/profile evidence.

For Arabic content changes outside the pilot, check the exact authoritative
Arabic source and spell out any differences with citations. Structural Unicode
checks cannot verify morphological accuracy or the vowel marks.

## Isolation and API policy

- The workflow for this repo has `contents: read` only and runs Flutter
  checks; **no `OPENAI_API_KEY`**, no model calls.
- Codex Cloud is the agent executor through the user's ChatGPT account,
  when that account has access and usage allowance. Repository CI is not
  a model executor.
- Do not copy private Android repositories into public AI-Council or public
  GitHub Actions artifacts. Open each private repo only in its own authorized
  protected Codex environment.
- There is no guarantee of unlimited Codex usage; plan limits apply.
