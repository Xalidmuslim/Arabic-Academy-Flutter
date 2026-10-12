import { readBody, serve, uuidField } from "../_shared/http.ts";
import { fcmCredentials, sendFcm } from "../_shared/fcm.ts";
import { authenticate, rpc } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request),
    body = await readBody(request),
    id = uuidField(body, "notification_id");
  const previous = await rpc<{ state: string; accepted_count: number; failed_count: number }>(
    "notification_dispatch_status",
    { p_notification_id: id },
    auth,
  );
  if (previous.state !== "not_dispatched") {
    return { ...previous, notification_id: id, duplicate: true };
  }
  const credentials = await fcmCredentials();
  const claim = await rpc<
    {
      duplicate: boolean;
      state?: string;
      accepted_count?: number;
      failed_count?: number;
      tokens?: string[];
      kind?: string;
      body?: Record<string, unknown>;
    }
  >("claim_notification_dispatch", { p_notification_id: id, p_actor_id: auth.userId });
  if (claim.duplicate) {
    return {
      duplicate: true,
      notification_id: id,
      state: claim.state,
      accepted_count: claim.accepted_count,
      failed_count: claim.failed_count,
    };
  }
  let accepted = 0, failed = 0;
  // Bound server fan-out; no registration tokens or OAuth data are returned to the caller.
  const outcomes = await Promise.all(
    (claim.tokens || []).map((token) =>
      sendFcm(credentials, token, { id, kind: claim.kind!, body: claim.body! })
    ),
  );
  for (const ok of outcomes) {
    if (ok) accepted++;
    else failed++;
  }
  const result = await rpc<Record<string, unknown>>("finish_notification_dispatch", {
    p_notification_id: id,
    p_accepted_count: accepted,
    p_failed_count: failed,
  });
  return { ...result, notification_id: id, duplicate: false };
});
if (import.meta.main) Deno.serve(handler);
