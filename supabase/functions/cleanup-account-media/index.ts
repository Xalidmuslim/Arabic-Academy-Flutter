import { ApiError, readRawBody, requiredEnv, serve } from "../_shared/http.ts";
import { verifyWebhook } from "../_shared/hmac.ts";
import { removeMediaBatch, rpc } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const raw = await readRawBody(request);
  await verifyWebhook(
    raw,
    request.headers.get("x-event-id") || "",
    request.headers.get("x-timestamp") || "",
    request.headers.get("x-signature") || "",
    requiredEnv("ACCOUNT_CLEANUP_HMAC_SECRET"),
  );
  let body;
  try {
    body = JSON.parse(raw);
  } catch {
    throw new ApiError(400, "invalid_json");
  }
  const limit = body?.max_jobs ?? 5;
  if (typeof limit !== "number" || !Number.isSafeInteger(limit) || limit < 1 || limit > 5) {
    throw new ApiError(400, "invalid_cleanup_limit");
  }
  const jobs = await rpc<
    { job_id: string; objects: { bucket_id: string; object_path: string }[] }[]
  >("claim_account_media_cleanup", { p_limit: limit });
  const results = await Promise.all(jobs.map(async (job) => {
    let success = false;
    try {
      await removeMediaBatch(job.objects);
      success = true;
    } catch { /* Retain a retryable lease; no sensitive response is logged. */ }
    await rpc("finish_account_media_cleanup", { p_job_id: job.job_id, p_success: success });
    return success;
  }));
  return { completed: results.filter(Boolean).length, failed: results.filter((x) => !x).length };
});
if (import.meta.main) Deno.serve(handler);
