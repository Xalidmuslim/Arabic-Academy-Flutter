import { exportPKCS8, generateKeyPair, jwtVerify } from "jose";
import { ApiError, readBody } from "./http.ts";
import { verifyWebhook } from "./hmac.ts";
import { googleClaimId, validateAppleTransaction, validateGooglePurchase } from "./stores.ts";
import { handler as livekit } from "../livekit-token/index.ts";
import { handler as grade } from "../grade-attempt/index.ts";
import { handler as media } from "../protected-media/index.ts";
import { handler as purchase } from "../verify-purchase/index.ts";
import { handler as stt } from "../transcribe/index.ts";
import { handler as webhook } from "../purchase-webhook/index.ts";
import { handler as upload } from "../media-upload/index.ts";
import { handler as remove } from "../delete-media/index.ts";
import { handler as exportAccount } from "../account-export/index.ts";
import { handler as deleteAccount } from "../account-delete/index.ts";
import { handler as dispatch } from "../dispatch-notification/index.ts";
import { handler as cleanupAccountMedia } from "../cleanup-account-media/index.ts";
const USER = "00000000-0000-0000-0000-000000000001";
function assert(ok: unknown, message = "assertion failed"): asserts ok {
  if (!ok) throw new Error(message);
}
function equal(a: unknown, b: unknown) {
  assert(
    JSON.stringify(a) === JSON.stringify(b),
    `expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`,
  );
}
async function rejects(fn: () => unknown | Promise<unknown>, code: string) {
  try {
    await fn();
  } catch (e) {
    assert(e instanceof ApiError);
    equal(e.code, code);
    return;
  }
  throw new Error(`Expected ${code}`);
}
function request(body: unknown, auth = true): Request {
  return new Request("https://edge.example/functions/v1/test", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(auth ? { authorization: "Bearer user-test-token" } : {}),
    },
    body: JSON.stringify(body),
  });
}
async function withRuntime(
  env: Record<string, string>,
  fetcher: typeof fetch,
  fn: () => Promise<void>,
) {
  const original = globalThis.fetch;
  const previous = new Map<string, string | undefined>();
  for (const [k, v] of Object.entries(env)) {
    previous.set(k, Deno.env.get(k));
    Deno.env.set(k, v);
  }
  globalThis.fetch = fetcher;
  try {
    await fn();
  } finally {
    globalThis.fetch = original;
    for (const [k, v] of previous) {
      if (v === undefined) Deno.env.delete(k);
      else Deno.env.set(k, v);
    }
  }
}
const BASE = {
  SUPABASE_URL: "https://supabase.test",
  SUPABASE_ANON_KEY: "anon-test",
  SUPABASE_SERVICE_ROLE_KEY: "service-test",
  ALLOWED_ORIGINS: "",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
Deno.test("all user endpoints reject missing authentication before provider calls", async () => {
  for (
    const handler of [
      livekit,
      grade,
      media,
      purchase,
      stt,
      upload,
      remove,
      exportAccount,
      deleteAccount,
      dispatch,
    ]
  ) {
    const response = await handler(request({}, false));
    equal(response.status, 401);
    equal((await response.json()).error, "authentication_required");
  }
});
Deno.test("invalid Supabase JWT fails without provider activity", async () => {
  let calls = 0;
  await withRuntime(BASE, async (url) => {
    calls++;
    assert(String(url).endsWith("/auth/v1/user"));
    return json({}, 401);
  }, async () => {
    const r = await purchase(request({ provider: "apple", success: true }));
    equal(r.status, 401);
    equal(calls, 1);
  });
});
Deno.test("client purchase success and role cannot bypass missing store configuration", async () => {
  await withRuntime({ ...BASE, APPLE_BUNDLE_ID: "" }, async () => json({ id: USER }), async () => {
    const r = await purchase(
      request({
        provider: "apple",
        transaction_id: "unverified",
        success: true,
        user_id: USER,
        role: "admin",
      }),
    );
    equal(r.status, 503);
    equal((await r.json()).error, "integration_unconfigured");
  });
});
Deno.test("server-scoped LiveKit grants ignore client privileges and bind identity", async () => {
  const secret = "livekit-test-secret-32-characters";
  let rpcCalls = 0;
  const env = {
    ...BASE,
    LIVEKIT_API_KEY: "test-key",
    LIVEKIT_API_SECRET: secret,
    LIVEKIT_URL: "wss://live.test",
  };
  await withRuntime(env, async (url, init) => {
    if (String(url).endsWith("/auth/v1/user")) return json({ id: USER });
    assert(String(url).endsWith("/rpc/live_session_access"));
    rpcCalls++;
    const args = JSON.parse(String(init?.body));
    equal(args, { p_session_id: USER, p_recording_consent: false });
    return json({
      room_name: "authorized_room",
      user_id: USER,
      can_publish: false,
      expires_at: new Date(Date.now() + 60000).toISOString(),
    });
  }, async () => {
    const r = await livekit(
      request({ session_id: USER, can_publish: true, room: "stolen_room", user_id: "attacker" }),
    );
    equal(r.status, 200);
    const data = await r.json();
    const verified = await jwtVerify(data.token, new TextEncoder().encode(secret), {
      issuer: "test-key",
      subject: USER,
    });
    equal(verified.payload.video, {
      roomJoin: true,
      room: "authorized_room",
      canPublish: false,
      canSubscribe: true,
      canPublishData: true,
      canUpdateOwnMetadata: false,
    });
    equal(rpcCalls, 1);
  });
});
Deno.test("live token does not mint if RPC identity differs", async () => {
  await withRuntime(
    { ...BASE, LIVEKIT_API_KEY: "k", LIVEKIT_API_SECRET: "s", LIVEKIT_URL: "wss://live.test" },
    async (url) => String(url).endsWith("/user") ? json({ id: USER }) : json({ user_id: "other" }),
    async () => {
      const r = await livekit(request({ session_id: USER }));
      equal(r.status, 403);
    },
  );
});
Deno.test("grading forwards user JWT and answers, never client score", async () => {
  await withRuntime(BASE, async (url, init) => {
    if (String(url).endsWith("/user")) return json({ id: USER });
    assert(String(url).endsWith("/rpc/submit_attempt"));
    equal(new Headers(init?.headers).get("authorization"), "Bearer user-test-token");
    const args = JSON.parse(String(init?.body));
    equal(args, { p_exercise_id: USER, p_idempotency_key: USER, p_answers: { q: "wrong" } });
    return json({ passed: false, score: 0, status: "graded" });
  }, async () => {
    const r = await grade(
      request({
        exercise_id: USER,
        idempotency_key: USER,
        answers: { q: "wrong" },
        passed: true,
        score: 100,
      }),
    );
    equal(r.status, 200);
    equal((await r.json()).attempt.passed, false);
  });
});
Deno.test("protected media signs only server-resolved path after user authorization", async () => {
  const calls: string[] = [];
  await withRuntime(BASE, async (url, init) => {
    calls.push(String(url));
    if (String(url).endsWith("/user")) return json({ id: USER });
    if (String(url).endsWith("/rpc/media_access")) {
      return json({
        media_id: USER,
        bucket_id: "course-media",
        object_path: "paid/a.mp3",
        expires_in: 30,
      });
    }
    assert(String(url).endsWith("/object/sign/course-media/paid/a.mp3"));
    equal(JSON.parse(String(init?.body)), { expiresIn: 30 });
    equal(new Headers(init?.headers).get("authorization"), "Bearer service-test");
    return json({ signedURL: "/object/sign/course-media/paid/a.mp3?token=test" });
  }, async () => {
    const r = await media(
      request({ media_id: USER, object_path: "other/private", expires_in: 999999 }),
    );
    equal(r.status, 200);
    equal((await r.json()).expires_in, 30);
    equal(calls.length, 3);
  });
});
Deno.test("denied paid media never reaches storage signer", async () => {
  let calls = 0;
  await withRuntime(BASE, async (url) => {
    calls++;
    if (String(url).endsWith("/user")) return json({ id: USER });
    return json({ code: "42501", message: "media_denied" }, 400);
  }, async () => {
    const r = await media(request({ media_id: USER }));
    equal(r.status, 403);
    equal(calls, 2);
  });
});
Deno.test("STT requires current consent and never sends denied audio to provider", async () => {
  let calls = 0;
  await withRuntime({ ...BASE, STT_OPENAI_API_KEY: "stt-test" }, async (url) => {
    calls++;
    if (String(url).endsWith("/user")) return json({ id: USER });
    assert(String(url).endsWith("/rpc/media_access"));
    return json({ code: "42501", message: "stt_consent_required" }, 400);
  }, async () => {
    const r = await stt(request({ media_id: USER }));
    equal(r.status, 403);
    equal(calls, 2);
  });
});
Deno.test("request stream bound and invalid JSON reject", async () => {
  await rejects(
    () =>
      readBody(
        new Request("https://test", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: "x".repeat(131073),
        }),
      ),
    "body_too_large",
  );
  await rejects(
    () =>
      readBody(
        new Request("https://test", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: "[]",
        }),
      ),
    "invalid_json",
  );
});
const apple = {
  transactionId: "tx1",
  bundleId: "app.test",
  environment: "Production",
  appAccountToken: USER,
  inAppOwnershipType: "PURCHASED",
  type: "Non-Consumable",
  productId: "course.paid",
  purchaseDate: Date.now() - 1000,
};
Deno.test("Apple verified claim parser rejects mismatched, revoked, sandbox, shared and expired claims", async () => {
  equal(validateAppleTransaction(apple, USER, "tx1", "app.test").accountBinding, USER);
  for (
    const patch of [
      { appAccountToken: "other" },
      { bundleId: "other" },
      { transactionId: "tx2" },
      { environment: "Sandbox" },
      { revocationDate: Date.now() },
      { inAppOwnershipType: "FAMILY_SHARED" },
      { type: "Consumable" },
      { type: "Auto-Renewable Subscription", expiresDate: Date.now() - 1000 },
    ]
  ) {
    await rejects(
      () => validateAppleTransaction({ ...apple, ...patch }, USER, "tx1", "app.test"),
      "purchase_not_verified",
    );
  }
});
const google = {
  purchaseState: 0,
  consumptionState: 0,
  obfuscatedExternalAccountId: USER,
  purchaseTimeMillis: String(Date.now() - 1000),
  quantity: 1,
};
Deno.test("Google verified claim parser rejects pending/refunded, consumed, test and unbound claims", async () => {
  equal(validateGooglePurchase(google, USER, "course", "course", "hash").expiresAt, null);
  for (
    const patch of [
      { purchaseState: 1 },
      { purchaseState: 2 },
      { consumptionState: 1 },
      { purchaseType: 0 },
      { obfuscatedExternalAccountId: "other" },
      { quantity: 2 },
    ]
  ) {
    await rejects(
      () => validateGooglePurchase({ ...google, ...patch }, USER, "course", "course", "hash"),
      "purchase_not_verified",
    );
  }
  assert((await googleClaimId("token")).length === 64);
});
Deno.test("Google subscription requires live expiry, matching product and bound account", async () => {
  const sub = {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    startTime: new Date(Date.now() - 1000).toISOString(),
    externalAccountIdentifiers: { obfuscatedExternalAccountId: USER },
    lineItems: [{ productId: "sub", expiryTime: new Date(Date.now() + 60000).toISOString() }],
  };
  assert(validateGooglePurchase(sub, USER, "sub", "subscription", "hash").expiresAt !== null);
  for (
    const patch of [{ subscriptionState: "SUBSCRIPTION_STATE_PENDING" }, { testPurchase: {} }, {
      lineItems: [{ productId: "other", expiryTime: new Date(Date.now() + 60000).toISOString() }],
    }, {
      lineItems: [{ productId: "sub", expiryTime: new Date(Date.now() - 60000).toISOString() }],
    }, { externalAccountIdentifiers: {} }]
  ) {
    await rejects(
      () => validateGooglePurchase({ ...sub, ...patch }, USER, "sub", "subscription", "hash"),
      "purchase_not_verified",
    );
  }
});
async function sign(raw: string, id: string, time: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const data = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${time}.${id}.${raw}`),
  );
  return Array.from(new Uint8Array(data), (b) => b.toString(16).padStart(2, "0")).join("");
}
Deno.test("webhook HMAC binds raw body, event ID and freshness", async () => {
  const secret = "a".repeat(32),
    now = 1700000000,
    time = String(now),
    raw = '{"action":"revoke"}',
    signature = await sign(raw, "event_1", time, secret);
  await verifyWebhook(raw, "event_1", time, signature, secret, now);
  for (
    const [body, id, ts, current] of [[raw + " ", "event_1", time, now], [
      raw,
      "event_2",
      time,
      now,
    ], [raw, "event_1", time, now + 301]] as const
  ) {
    await rejects(
      () => verifyWebhook(body, id, ts, signature, secret, current),
      "invalid_webhook_signature",
    );
  }
});
Deno.test("webhook forwards bound event to service RPC, never accepts grant action", async () => {
  const secret = "b".repeat(32), id = "event_2", time = String(Math.floor(Date.now() / 1000));
  let calls = 0;
  const body = {
      provider: "apple",
      action: "revoke",
      transaction_id: "tx1",
      account_binding: USER,
    },
    raw = JSON.stringify(body),
    signature = await sign(raw, id, time, secret);
  await withRuntime({ ...BASE, PURCHASE_WEBHOOK_HMAC_SECRET: secret }, async (url, init) => {
    calls++;
    assert(String(url).endsWith("/rpc/apply_purchase_webhook"));
    const args = JSON.parse(String(init?.body));
    equal(args.p_payload, body);
    equal(args.p_event_id, id);
    equal(args.p_account_binding, USER);
    return json({ duplicate: false });
  }, async () => {
    const req = new Request("https://test", {
      method: "POST",
      headers: { "x-event-id": id, "x-timestamp": time, "x-signature": signature },
      body: raw,
    });
    equal((await webhook(req)).status, 200);
    equal(calls, 1);
    const changed = { ...body, action: "grant" }, text = JSON.stringify(changed);
    const bad = new Request("https://test", {
      method: "POST",
      headers: {
        "x-event-id": id,
        "x-timestamp": time,
        "x-signature": await sign(text, id, time, secret),
      },
      body: text,
    });
    equal((await webhook(bad)).status, 400);
    equal(calls, 1);
  });
});
Deno.test("disallowed browser origins reject with no upstream request", async () => {
  await withRuntime({ ...BASE, ALLOWED_ORIGINS: "https://allowed.example" }, async () => {
    throw new Error("unexpected fetch");
  }, async () => {
    const req = request({}, false);
    req.headers.set("origin", "https://other.example");
    equal((await grade(req)).status, 403);
  });
});
Deno.test("upload ticket binds a server path and file policy, never client path", async () => {
  await withRuntime(BASE, async (url, init) => {
    if (String(url).endsWith("/user")) return json({ id: USER });
    if (String(url).endsWith("/rpc/prepare_media_upload")) {
      equal(JSON.parse(String(init?.body)), {
        p_lesson_id: null,
        p_mime_type: "audio/mp4",
        p_byte_size: 3,
        p_consent_stt: false,
      });
      return json({
        media_id: USER,
        bucket_id: "student-media",
        object_path: `${USER}/safe.m4a`,
        mime_type: "audio/mp4",
        byte_size: 3,
        upload_state: "pending",
      });
    }
    assert(String(url).endsWith(`/object/upload/sign/student-media/${USER}/safe.m4a`));
    equal(new Headers(init?.headers).get("x-upsert"), "false");
    return json({ url: "/object/upload/sign/student-media/safe.m4a?token=upload-token" });
  }, async () => {
    const r = await upload(
      request({
        action: "begin",
        filename: "../../../private.m4a",
        byte_size: 3,
        mime_type: "audio/mp4",
        object_path: "private/stolen",
      }),
    );
    equal(r.status, 200);
    const data = await r.json();
    equal(data.token, "upload-token");
    equal(data.object_path, `${USER}/safe.m4a`);
  });
});
Deno.test("upload completion binds actor and rejects claimed client metadata", async () => {
  await withRuntime(BASE, async (url, init) => {
    if (String(url).endsWith("/user")) return json({ id: USER });
    if (String(url).endsWith("/rpc/media_upload_access")) return json({});
    assert(String(url).endsWith("/rpc/finalize_media_upload"));
    equal(JSON.parse(String(init?.body)), { p_media_id: USER, p_actor_id: USER });
    return json({ code: "42501", message: "upload_metadata_mismatch" }, 400);
  }, async () => {
    const r = await upload(
      request({
        action: "complete",
        media_id: USER,
        byte_size: 3,
        mime_type: "audio/mp4",
        user_id: "other",
      }),
    );
    equal(r.status, 403);
  });
});
Deno.test("media deletion does not acknowledge success if storage fails", async () => {
  let calls = 0;
  await withRuntime(BASE, async (url) => {
    calls++;
    if (String(url).endsWith("/user")) return json({ id: USER });
    if (String(url).endsWith("/rpc/media_upload_access")) {
      return json({ bucket_id: "student-media", object_path: "safe" });
    }
    assert(String(url).endsWith("/object/student-media"));
    return json({}, 503);
  }, async () => {
    equal((await remove(request({ media_id: USER }))).status, 502);
    equal(calls, 3);
  });
});
Deno.test("STT rechecks consent after downloading and never transmits withdrawn audio", async () => {
  let accessCalls = 0;
  let providerCalls = 0;
  await withRuntime({ ...BASE, STT_OPENAI_API_KEY: "test" }, async (url) => {
    const path = String(url);
    if (path.endsWith("/user")) return json({ id: USER });
    if (path.endsWith("/rpc/media_access")) {
      accessCalls++;
      if (accessCalls === 2) return json({ code: "42501", message: "stt_consent_required" }, 400);
      return json({
        media_id: USER,
        bucket_id: "student-media",
        object_path: "safe.m4a",
        mime_type: "audio/mp4",
        byte_size: 3,
        expires_in: 60,
      });
    }
    if (path.endsWith("/rpc/reserve_stt_request")) return json(USER);
    if (path.includes("/storage/v1/object/sign/") && !path.includes("?")) {
      return json({ signedURL: "/object/sign/student-media/safe.m4a?token=test" });
    }
    if (path.includes("?token=test")) return new Response(new Uint8Array([1, 2, 3]));
    providerCalls++;
    throw new Error("unexpected STT provider request");
  }, async () => {
    equal((await stt(request({ media_id: USER }))).status, 403);
    equal(accessCalls, 2);
    equal(providerCalls, 0);
  });
});
Deno.test("STT returns transcription only after consent and a successful provider response", async () => {
  await withRuntime({ ...BASE, STT_OPENAI_API_KEY: "test" }, async (url, init) => {
    const path = String(url);
    if (path.endsWith("/user")) return json({ id: USER });
    if (path.endsWith("/rpc/media_access")) {
      return json({
        media_id: USER,
        bucket_id: "student-media",
        object_path: "safe.m4a",
        mime_type: "audio/mp4",
        byte_size: 3,
        expires_in: 60,
      });
    }
    if (path.endsWith("/rpc/reserve_stt_request")) return json(USER);
    if (path.includes("/storage/v1/object/sign/") && !path.includes("?")) {
      return json({ signedURL: "/object/sign/student-media/safe.m4a?token=test" });
    }
    if (path.includes("?token=test")) return new Response(new Uint8Array([1, 2, 3]));
    equal(path, "https://api.openai.com/v1/audio/transcriptions");
    assert(init?.body instanceof FormData);
    equal(init.body.get("model"), "whisper-1");
    equal(init.body.get("language"), "ar");
    return json({ text: "نَعَمْ" });
  }, async () => {
    const r = await stt(request({ media_id: USER }));
    equal(r.status, 200);
    equal(await r.json(), {
      text: "نَعَمْ",
      language: "ar",
      provider: "openai",
      assessment: "transcription_only",
    });
  });
});
Deno.test("account export uses owner JWT and allowlists identity, never request user or provider secrets", async () => {
  await withRuntime(BASE, async (url, init) => {
    if (String(url).endsWith("/user")) {
      return json({
        id: USER,
        phone: "+10000000000",
        email: "",
        created_at: "2026-01-01",
        access_token: "secret",
        app_metadata: { secret: "hidden" },
      });
    }
    assert(String(url).endsWith("/rpc/account_export"));
    equal(new Headers(init?.headers).get("authorization"), "Bearer user-test-token");
    equal(JSON.parse(String(init?.body)), { p_max_rows: 5000 });
    return json({ account_id: USER, data: { profiles: [] } });
  }, async () => {
    const res = await exportAccount(request({ user_id: "attacker", include_secrets: true }));
    equal(res.status, 200);
    const data = await res.json();
    equal(data.account_id, USER);
    equal(data.identity, { id: USER, phone: "+10000000000", email: "", created_at: "2026-01-01" });
    assert(!JSON.stringify(data).includes("secret"));
  });
});
Deno.test("account deletion requires explicit true confirmation before mutation", async () => {
  let calls = 0;
  await withRuntime(BASE, async () => {
    calls++;
    return json({ id: USER });
  }, async () => {
    equal((await deleteAccount(request({ confirm: "true" }))).status, 400);
    equal(calls, 1);
  });
});
Deno.test("account deletion cleans bounded private objects, purges bound user then hard deletes Auth", async () => {
  const calls: string[] = [];
  await withRuntime(BASE, async (url, init) => {
    const path = String(url);
    calls.push(path);
    if (path.endsWith("/user")) return json({ id: USER });
    if (path.endsWith("/rpc/request_account_deletion")) {
      return json({
        account_id: USER,
        objects: [{ bucket_id: "student-media", object_path: "own/audio.m4a" }],
      });
    }
    if (path.endsWith("/object/student-media")) {
      equal(init?.method, "DELETE");
      equal(JSON.parse(String(init?.body)), { prefixes: ["own/audio.m4a"] });
      return json([]);
    }
    if (path.endsWith("/rpc/purge_account_data")) {
      equal(JSON.parse(String(init?.body)), { p_user_id: USER });
      return json(null);
    }
    assert(path.endsWith(`/auth/v1/admin/users/${USER}`));
    equal(init?.method, "DELETE");
    equal(JSON.parse(String(init?.body)), { should_soft_delete: false });
    return json({});
  }, async () => {
    const r = await deleteAccount(request({ confirm: true, user_id: "attacker" }));
    equal(r.status, 200);
    equal(await r.json(), {
      deleted: true,
      account_id: USER,
      store_subscriptions_cancelled: false,
      storage_cleanup_pending: true,
      cleanup_not_before: null,
    });
    equal(calls.length, 5);
  });
});
Deno.test("account deletion does not claim completion when Auth admin delete fails", async () => {
  await withRuntime(BASE, async (url) => {
    const path = String(url);
    if (path.endsWith("/user")) return json({ id: USER });
    if (path.endsWith("/rpc/request_account_deletion")) {
      return json({ account_id: USER, objects: [] });
    }
    if (path.endsWith("/rpc/purge_account_data")) return json(null);
    return json({}, 503);
  }, async () => {
    const r = await deleteAccount(request({ confirm: true }));
    equal(r.status, 502);
    equal((await r.json()).error, "account_delete_pending");
  });
});
Deno.test("notification sender fails closed before claim when FCM is unconfigured", async () => {
  let calls = 0;
  await withRuntime({ ...BASE, FCM_SERVICE_ACCOUNT_JSON: "" }, async (url) => {
    calls++;
    if (String(url).endsWith("/user")) return json({ id: USER });
    assert(String(url).endsWith("/rpc/notification_dispatch_status"));
    return json({ state: "not_dispatched" });
  }, async () => {
    const r = await dispatch(request({ notification_id: USER }));
    equal(r.status, 503);
    equal(calls, 2);
  });
});
Deno.test("notification replay never calls FCM or repeats a reserved send", async () => {
  let calls = 0;
  await withRuntime(BASE, async (url) => {
    calls++;
    if (String(url).endsWith("/user")) return json({ id: USER });
    return json({ notification_id: USER, state: "accepted", accepted_count: 1, failed_count: 0 });
  }, async () => {
    const r = await dispatch(request({ notification_id: USER }));
    equal(r.status, 200);
    const replay = await r.json();
    equal(replay.duplicate, true);
    equal(replay.notification_id, USER);
    equal(calls, 2);
  });
});
Deno.test("FCM sender obtains scoped OAuth and returns provider acceptance without tokens", async () => {
  const pair = await generateKeyPair("RS256", { extractable: true });
  const privateKey = await exportPKCS8(pair.privateKey);
  const account = {
    project_id: "bayna-test",
    client_email: "sender@bayna-test.iam.gserviceaccount.com",
    private_key: privateKey,
  };
  await withRuntime(
    { ...BASE, FCM_SERVICE_ACCOUNT_JSON: JSON.stringify(account) },
    async (url, init) => {
      const path = String(url);
      if (path.endsWith("/user")) return json({ id: USER });
      if (path.endsWith("/rpc/notification_dispatch_status")) {
        return json({
          state: "not_dispatched",
        });
      }
      if (path === "https://oauth2.googleapis.com/token") {
        assert(init?.body instanceof URLSearchParams);
        const jwt = await jwtVerify(init.body.get("assertion")!, pair.publicKey, {
          audience: "https://oauth2.googleapis.com/token",
        });
        equal(jwt.payload.scope, "https://www.googleapis.com/auth/firebase.messaging");
        return json({ access_token: "provider-token" });
      }
      if (path.endsWith("/rpc/claim_notification_dispatch")) {
        equal(JSON.parse(String(init?.body)), { p_notification_id: USER, p_actor_id: USER });
        return json({
          duplicate: false,
          kind: "assignment",
          body: { title: "Homework", text: "Study" },
          tokens: ["private-device-token"],
        });
      }
      if (path === "https://fcm.googleapis.com/v1/projects/bayna-test/messages:send") {
        equal(new Headers(init?.headers).get("authorization"), "Bearer provider-token");
        const payload = JSON.parse(String(init?.body));
        equal(payload.message.token, "private-device-token");
        equal(payload.message.data.notification_id, USER);
        return json({ name: "projects/bayna-test/messages/message-1" });
      }
      assert(path.endsWith("/rpc/finish_notification_dispatch"));
      equal(JSON.parse(String(init?.body)), {
        p_notification_id: USER,
        p_accepted_count: 1,
        p_failed_count: 0,
      });
      return json({ state: "accepted", accepted_count: 1, failed_count: 0 });
    },
    async () => {
      const r = await dispatch(request({ notification_id: USER, recipient: "forged" }));
      equal(r.status, 200);
      const data = await r.json();
      equal(data.state, "accepted");
      equal(data.notification_id, USER);
      assert(!JSON.stringify(data).includes("token"));
    },
  );
});
Deno.test("account cleanup rejects user JWT without scheduler HMAC before database access", async () => {
  await withRuntime({ ...BASE, ACCOUNT_CLEANUP_HMAC_SECRET: "c".repeat(32) }, async () => {
    throw new Error("unexpected fetch");
  }, async () => {
    const r = await cleanupAccountMedia(request({ max_jobs: 5 }));
    equal(r.status, 401);
  });
});
Deno.test("account cleanup removes only leased server paths then records actual completion", async () => {
  const secret = "d".repeat(32),
    id = "cleanup_event_1",
    time = String(Math.floor(Date.now() / 1000)),
    raw = JSON.stringify({ max_jobs: 1, objects: ["forged/private"] });
  await withRuntime({ ...BASE, ACCOUNT_CLEANUP_HMAC_SECRET: secret }, async (url, init) => {
    const path = String(url);
    if (path.endsWith("/rpc/claim_account_media_cleanup")) {
      equal(JSON.parse(String(init?.body)), { p_limit: 1 });
      return json([{
        job_id: USER,
        objects: [{ bucket_id: "student-media", object_path: "server/owned.m4a" }],
      }]);
    }
    if (path.endsWith("/object/student-media")) {
      equal(JSON.parse(String(init?.body)), { prefixes: ["server/owned.m4a"] });
      return json([]);
    }
    assert(path.endsWith("/rpc/finish_account_media_cleanup"));
    equal(JSON.parse(String(init?.body)), { p_job_id: USER, p_success: true });
    return json(null);
  }, async () => {
    const req = new Request("https://test", {
      method: "POST",
      headers: {
        "x-event-id": id,
        "x-timestamp": time,
        "x-signature": await sign(raw, id, time, secret),
      },
      body: raw,
    });
    const r = await cleanupAccountMedia(req);
    equal(r.status, 200);
    equal(await r.json(), { completed: 1, failed: 0 });
  });
});
Deno.test("Google cancellation and grace retain verified future-expiry access", async () => {
  const sub = {
    startTime: new Date(Date.now() - 1000).toISOString(),
    externalAccountIdentifiers: { obfuscatedExternalAccountId: USER },
    lineItems: [{ productId: "sub", expiryTime: new Date(Date.now() + 60000).toISOString() }],
  };
  for (const state of ["SUBSCRIPTION_STATE_CANCELED", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"]) {
    assert(
      validateGooglePurchase(
        { ...sub, subscriptionState: state },
        USER,
        "sub",
        "subscription",
        "hash",
      ).expiresAt !== null,
    );
  }
  for (
    const state of [
      "SUBSCRIPTION_STATE_PAUSED",
      "SUBSCRIPTION_STATE_PENDING",
      "SUBSCRIPTION_STATE_ON_HOLD",
      "SUBSCRIPTION_STATE_EXPIRED",
      "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
      "SUBSCRIPTION_STATE_REFUNDED",
    ]
  ) {
    await rejects(
      () =>
        validateGooglePurchase(
          { ...sub, subscriptionState: state },
          USER,
          "sub",
          "subscription",
          "hash",
        ),
      "purchase_not_verified",
    );
  }
  for (const state of ["SUBSCRIPTION_STATE_CANCELED", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"]) {
    await rejects(
      () =>
        validateGooglePurchase(
          {
            ...sub,
            subscriptionState: state,
            lineItems: [{
              productId: "sub",
              expiryTime: new Date(Date.now() - 1000).toISOString(),
            }],
          },
          USER,
          "sub",
          "subscription",
          "hash",
        ),
      "purchase_not_verified",
    );
    await rejects(
      () =>
        validateGooglePurchase(
          {
            ...sub,
            subscriptionState: state,
            externalAccountIdentifiers: { obfuscatedExternalAccountId: "other" },
          },
          USER,
          "sub",
          "subscription",
          "hash",
        ),
      "purchase_not_verified",
    );
  }
});
Deno.test("licensed sandbox claims require both server test flag and test deployment", async () => {
  await withRuntime(
    { STORE_TEST_ENVIRONMENT: "true", DEPLOYMENT_ENVIRONMENT: "test" },
    async () => {
      throw new Error("unexpected network");
    },
    async () => {
      equal(
        validateAppleTransaction({ ...apple, environment: "Sandbox" }, USER, "tx1", "app.test")
          .accountBinding,
        USER,
      );
      equal(
        validateGooglePurchase({ ...google, purchaseType: 0 }, USER, "course", "course", "hash")
          .accountBinding,
        USER,
      );
      const sub = {
        subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
        testPurchase: {},
        startTime: new Date(Date.now() - 1000).toISOString(),
        externalAccountIdentifiers: { obfuscatedExternalAccountId: USER },
        lineItems: [{ productId: "sub", expiryTime: new Date(Date.now() + 60000).toISOString() }],
      };
      assert(validateGooglePurchase(sub, USER, "sub", "subscription", "hash").expiresAt !== null);
    },
  );
  await withRuntime(
    { STORE_TEST_ENVIRONMENT: "true", DEPLOYMENT_ENVIRONMENT: "production" },
    async () => {
      throw new Error("unexpected network");
    },
    async () => {
      await rejects(
        () =>
          validateAppleTransaction({ ...apple, environment: "Sandbox" }, USER, "tx1", "app.test"),
        "invalid_store_test_configuration",
      );
      await rejects(
        () =>
          validateGooglePurchase({ ...google, purchaseType: 0 }, USER, "course", "course", "hash"),
        "invalid_store_test_configuration",
      );
    },
  );
  await withRuntime({ STORE_TEST_ENVIRONMENT: "", DEPLOYMENT_ENVIRONMENT: "test" }, async () => {
    throw new Error("unexpected network");
  }, async () => {
    await rejects(
      () => validateAppleTransaction({ ...apple, environment: "Sandbox" }, USER, "tx1", "app.test"),
      "purchase_not_verified",
    );
    await rejects(
      () =>
        validateGooglePurchase({ ...google, purchaseType: 0 }, USER, "course", "course", "hash"),
      "purchase_not_verified",
    );
  });
});
Deno.test("category denial occurs before FCM OAuth or reservation for all stable categories", async () => {
  for (const category of ["lesson", "assignment", "live", "feedback", "message", "review"]) {
    let calls = 0;
    await withRuntime(BASE, async (url) => {
      calls++;
      if (String(url).endsWith("/user")) return json({ id: USER });
      assert(String(url).endsWith("/rpc/notification_dispatch_status"));
      return json({ code: "42501", message: "notification_category_disabled" }, 400);
    }, async () => {
      const r = await dispatch(request({ notification_id: USER, category }));
      equal(r.status, 403);
      equal(calls, 2);
    });
  }
});
Deno.test("concurrent dispatch replay includes notification ID and never sends again", async () => {
  const pair = await generateKeyPair("RS256", { extractable: true }),
    privateKey = await exportPKCS8(pair.privateKey);
  await withRuntime({
    ...BASE,
    FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({
      project_id: "bayna-test",
      client_email: "sender@test",
      private_key: privateKey,
    }),
  }, async (url) => {
    const path = String(url);
    if (path.endsWith("/user")) return json({ id: USER });
    if (path.endsWith("/rpc/notification_dispatch_status")) {
      return json({ state: "not_dispatched" });
    }
    if (path === "https://oauth2.googleapis.com/token") return json({ access_token: "token" });
    assert(path.endsWith("/rpc/claim_notification_dispatch"));
    return json({ duplicate: true, state: "reserved", accepted_count: 0, failed_count: 0 });
  }, async () => {
    const r = await dispatch(request({ notification_id: USER }));
    equal(r.status, 200);
    equal((await r.json()).notification_id, USER);
  });
});
Deno.test("host LiveKit scope permits audio/video and data but no administration", async () => {
  const secret = "host-test-secret-32-characters";
  await withRuntime(
    { ...BASE, LIVEKIT_API_KEY: "key", LIVEKIT_API_SECRET: secret, LIVEKIT_URL: "wss://live.test" },
    async (url) =>
      String(url).endsWith("/user") ? json({ id: USER }) : json({
        room_name: "host_room",
        user_id: USER,
        can_publish: true,
        expires_at: new Date(Date.now() + 60000).toISOString(),
      }),
    async () => {
      const r = await livekit(request({ session_id: USER }));
      equal(r.status, 200);
      const data = await r.json();
      const verified = await jwtVerify(data.token, new TextEncoder().encode(secret));
      const grants = verified.payload.video as Record<string, unknown>;
      equal(grants.canPublish, true);
      equal(grants.canPublishData, true);
      assert(!grants.roomAdmin && !grants.roomCreate && !grants.roomRecord);
    },
  );
});
