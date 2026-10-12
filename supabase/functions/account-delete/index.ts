import { ApiError, readBody, requiredEnv, serve } from "../_shared/http.ts";
import { authenticate, deleteAuthUser, removeMediaBatch, rpc } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request), body = await readBody(request);
  if (body.confirm !== true) throw new ApiError(400, "deletion_confirmation_required");
  requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const plan = await rpc<
    {
      account_id: string;
      objects: { bucket_id: string; object_path: string }[];
      cleanup_not_before?: string;
    }
  >("request_account_deletion", { p_confirm: true }, auth);
  if (
    plan.account_id !== auth.userId || !Array.isArray(plan.objects) || plan.objects.length > 200
  ) throw new ApiError(403, "identity_mismatch");
  // Remove every owned upload before database references; other users' uploads are untouched.
  await removeMediaBatch(plan.objects);
  await rpc("purge_account_data", { p_user_id: auth.userId });
  await deleteAuthUser(auth.userId);
  return {
    deleted: true,
    account_id: auth.userId,
    store_subscriptions_cancelled: false,
    storage_cleanup_pending: true,
    cleanup_not_before: plan.cleanup_not_before ?? null,
  };
});
if (import.meta.main) Deno.serve(handler);
