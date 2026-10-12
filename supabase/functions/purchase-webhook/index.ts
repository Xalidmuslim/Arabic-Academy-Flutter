import {
  ApiError,
  readRawBody,
  requiredEnv,
  serve,
  stringField,
  uuidField,
} from "../_shared/http.ts";
import { verifyWebhook } from "../_shared/hmac.ts";
import { rpc } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const raw = await readRawBody(request),
    id = request.headers.get("x-event-id") || "",
    timestamp = request.headers.get("x-timestamp") || "";
  await verifyWebhook(
    raw,
    id,
    timestamp,
    request.headers.get("x-signature") || "",
    requiredEnv("PURCHASE_WEBHOOK_HMAC_SECRET"),
  );
  let body;
  try {
    body = JSON.parse(raw);
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error();
  } catch {
    throw new ApiError(400, "invalid_json");
  }
  const provider = stringField(body, "provider");
  if (!["apple", "google"].includes(provider) || body.action !== "revoke") {
    throw new ApiError(400, "unsupported_webhook");
  }
  return await rpc("apply_purchase_webhook", {
    p_provider: provider,
    p_event_id: id,
    p_transaction_id: stringField(body, "transaction_id", 256),
    p_account_binding: uuidField(body, "account_binding"),
    p_action: "revoke",
    p_payload: body,
  });
});
if (import.meta.main) Deno.serve(handler);
