import { readBody, serve, uuidField } from "../_shared/http.ts";
import { authenticate, MediaAccess, rpc, signMedia } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request), body = await readBody(request);
  const access = await rpc<MediaAccess>("media_access", {
    p_media_id: uuidField(body, "media_id"),
    p_for_stt: false,
  }, auth);
  return { url: await signMedia(access), expires_in: access.expires_in };
});
if (import.meta.main) Deno.serve(handler);
