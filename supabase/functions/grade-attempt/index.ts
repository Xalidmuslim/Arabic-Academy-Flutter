import { ApiError, readBody, serve, uuidField } from "../_shared/http.ts";
import { authenticate, rpc } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request), body = await readBody(request);
  if (!body.answers || typeof body.answers !== "object" || Array.isArray(body.answers)) {
    throw new ApiError(400, "invalid_answers");
  }
  return {
    attempt: await rpc("submit_attempt", {
      p_exercise_id: uuidField(body, "exercise_id"),
      p_idempotency_key: uuidField(body, "idempotency_key"),
      p_answers: body.answers,
    }, auth),
  };
});
if (import.meta.main) Deno.serve(handler);
