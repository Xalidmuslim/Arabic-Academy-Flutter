import { readBody, serve, uuidField } from "../_shared/http.ts";
import { authenticate, MediaAccess, removeMedia, rpc } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request),
    body = await readBody(request),
    id = uuidField(body, "media_id");
  const access = await rpc<MediaAccess>("media_upload_access", { p_media_id: id }, auth);
  await removeMedia(access);
  await rpc("mark_media_deleted", { p_media_id: id, p_actor_id: auth.userId });
  return { deleted: true, media_id: id };
});
if (import.meta.main) Deno.serve(handler);
