import { ApiError, readBody, serve } from "../_shared/http.ts";
import { authenticate, rpc } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request), body = await readBody(request);
  const max = body.max_rows ?? 5000;
  if (typeof max !== "number" || !Number.isSafeInteger(max) || max < 1 || max > 5000) {
    throw new ApiError(400, "invalid_export_limit");
  }
  const data = await rpc<Record<string, unknown>>("account_export", { p_max_rows: max }, auth);
  return { ...data, identity: auth.identity };
});
if (import.meta.main) Deno.serve(handler);
