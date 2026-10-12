import {
  ApiError,
  checkedFetch,
  readBody,
  requiredEnv,
  serve,
  uuidField,
} from "../_shared/http.ts";
import { authenticate, MediaAccess, rpc, signMedia } from "../_shared/supabase.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request), body = await readBody(request);
  const key = requiredEnv("STT_OPENAI_API_KEY");
  const media = await rpc<MediaAccess>("media_access", {
    p_media_id: uuidField(body, "media_id"),
    p_for_stt: true,
  }, auth);
  await rpc("reserve_stt_request", { p_media_id: media.media_id }, auth);
  const response = await checkedFetch(await signMedia(media));
  if (!response.ok) throw new ApiError(502, "storage_unavailable");
  // Enforce actual byte count even if metadata is stale; do not buffer oversized objects.
  const reader = response.body?.getReader();
  if (!reader) throw new ApiError(502, "invalid_media");
  const parts: Uint8Array<ArrayBuffer>[] = [];
  let bytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    bytes += value.length;
    if (bytes > 25000000) {
      await reader.cancel();
      throw new ApiError(413, "audio_too_large");
    }
    parts.push(new Uint8Array(value));
  }
  if (bytes === 0) throw new ApiError(400, "empty_audio");
  // Recheck consent after download, immediately before transmission to the third party.
  await rpc("media_access", { p_media_id: media.media_id, p_for_stt: true }, auth);
  const extensions: Record<string, string> = {
    "audio/mpeg": "mp3",
    "audio/mp4": "m4a",
    "audio/wav": "wav",
    "audio/webm": "webm",
    "audio/ogg": "ogg",
  };
  if (!extensions[media.mime_type]) throw new ApiError(400, "unsupported_audio");
  const form = new FormData();
  form.set(
    "file",
    new Blob(parts, { type: media.mime_type }),
    `speech.${extensions[media.mime_type]}`,
  );
  form.set("model", "whisper-1");
  form.set("language", "ar");
  form.set("response_format", "json");
  const result = await checkedFetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: { authorization: `Bearer ${key}` },
    body: form,
  });
  if (!result.ok) throw new ApiError(502, "stt_provider_failed");
  const data = await result.json();
  if (typeof data.text !== "string") throw new ApiError(502, "invalid_stt_response");
  return { text: data.text, language: "ar", provider: "openai", assessment: "transcription_only" };
});
if (import.meta.main) Deno.serve(handler);
