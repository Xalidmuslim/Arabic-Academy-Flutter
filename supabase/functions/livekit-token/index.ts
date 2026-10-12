import { SignJWT } from "jose";
import {
  ApiError,
  booleanField,
  readBody,
  requiredEnv,
  serve,
  uuidField,
} from "../_shared/http.ts";
import { authenticate, rpc } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request);
  const body = await readBody(request);
  // Require integration before writing attendance.
  const key = requiredEnv("LIVEKIT_API_KEY"),
    secret = requiredEnv("LIVEKIT_API_SECRET"),
    url = requiredEnv("LIVEKIT_URL");
  if (!url.startsWith("wss://")) throw new ApiError(503, "invalid_livekit_url");
  const access = await rpc<
    { room_name: string; user_id: string; can_publish: boolean; expires_at: string }
  >("live_session_access", {
    p_session_id: uuidField(body, "session_id"),
    p_recording_consent: booleanField(body, "recording_consent"),
  }, auth);
  if (access.user_id !== auth.userId) throw new ApiError(403, "identity_mismatch");
  const expires = Math.floor(new Date(access.expires_at).getTime() / 1000);
  const token = await new SignJWT({
    video: {
      roomJoin: true,
      room: access.room_name,
      canPublish: access.can_publish,
      canSubscribe: true,
      canPublishData: true,
      canUpdateOwnMetadata: false,
    },
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" }).setIssuer(key).setSubject(auth.userId)
    .setIssuedAt().setNotBefore(Math.floor(Date.now() / 1000) - 5).setExpirationTime(expires)
    .sign(new TextEncoder().encode(secret));
  return { token, url, expires_at: access.expires_at, can_publish: access.can_publish };
});
if (import.meta.main) Deno.serve(handler);
