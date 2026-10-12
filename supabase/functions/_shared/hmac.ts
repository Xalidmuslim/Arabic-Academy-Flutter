import { ApiError } from "./http.ts";
export async function verifyWebhook(
  raw: string,
  eventId: string,
  timestamp: string,
  signature: string,
  secret: string,
  now = Math.floor(Date.now() / 1000),
): Promise<void> {
  if (secret.length < 32) throw new ApiError(503, "invalid_webhook_configuration");
  if (
    !/^[A-Za-z0-9_-]{1,128}$/.test(eventId) || !/^\d{10}$/.test(timestamp) ||
    Math.abs(now - Number(timestamp)) > 300 || !/^[a-f0-9]{64}$/.test(signature)
  ) throw new ApiError(401, "invalid_webhook_signature");
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const bytes = new Uint8Array(signature.match(/../g)!.map((x) => parseInt(x, 16)));
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    bytes,
    new TextEncoder().encode(`${timestamp}.${eventId}.${raw}`),
  );
  if (!valid) throw new ApiError(401, "invalid_webhook_signature");
}
