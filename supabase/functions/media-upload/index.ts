import {
  ApiError,
  booleanField,
  readBody,
  serve,
  stringField,
  uuidField,
} from "../_shared/http.ts";
import { authenticate, MediaAccess, rpc, signUpload } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request),
    body = await readBody(request),
    action = stringField(body, "action");
  if (action === "begin") {
    stringField(body, "filename", 255); // Display-only; server assigns the path and extension.
    if (
      typeof body.byte_size !== "number" || !Number.isSafeInteger(body.byte_size) ||
      body.byte_size <= 0
    ) throw new ApiError(400, "invalid_byte_size");
    const access = await rpc<MediaAccess>("prepare_media_upload", {
      p_lesson_id: body.lesson_id == null ? null : uuidField(body, "lesson_id"),
      p_mime_type: stringField(body, "mime_type", 100),
      p_byte_size: body.byte_size,
      p_consent_stt: booleanField(body, "consent_stt"),
    }, auth);
    return { ...access, token: await signUpload(access) };
  }
  if (action === "complete") {
    const id = uuidField(body, "media_id");
    await rpc("media_upload_access", { p_media_id: id }, auth);
    const media = await rpc("finalize_media_upload", { p_media_id: id, p_actor_id: auth.userId });
    return { media };
  }
  throw new ApiError(400, "invalid_action");
});
if (import.meta.main) Deno.serve(handler);
