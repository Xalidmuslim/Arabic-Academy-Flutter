export class ApiError extends Error {
  constructor(public status: number, public code: string) {
    super(code);
  }
}
export function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new ApiError(503, "integration_unconfigured");
  return value;
}
export function stringField(body: Record<string, unknown>, key: string, max = 2048): string {
  const value = body[key];
  if (typeof value !== "string" || !value.trim() || value.length > max) {
    throw new ApiError(400, `invalid_${key}`);
  }
  return value;
}
export function uuidField(body: Record<string, unknown>, key: string): string {
  const value = stringField(body, key, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
    throw new ApiError(400, `invalid_${key}`);
  }
  return value.toLowerCase();
}
export function booleanField(body: Record<string, unknown>, key: string): boolean {
  if (body[key] === undefined) return false;
  if (typeof body[key] !== "boolean") throw new ApiError(400, `invalid_${key}`);
  return body[key];
}
export async function readBody(request: Request): Promise<Record<string, unknown>> {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    throw new ApiError(415, "json_required");
  }
  const raw = await readRawBody(request);
  try {
    const body = JSON.parse(raw);
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error();
    return body;
  } catch {
    throw new ApiError(400, "invalid_json");
  }
}
export async function readRawBody(request: Request): Promise<string> {
  // Bound the stream before materializing it, including chunked requests.
  const reader = request.body?.getReader();
  if (!reader) throw new ApiError(400, "empty_body");
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > 131072) {
      await reader.cancel();
      throw new ApiError(413, "body_too_large");
    }
    chunks.push(value);
  }
  const data = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    data.set(chunk, offset);
    offset += chunk.length;
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(data);
}
export async function checkedFetch(url: string, init?: RequestInit): Promise<Response> {
  try {
    return await fetch(url, { ...init, redirect: "error", signal: AbortSignal.timeout(15000) });
  } catch {
    throw new ApiError(502, "provider_unavailable");
  }
}
export function serve(handler: (request: Request) => Promise<unknown>) {
  return async (request: Request): Promise<Response> => {
    const headers = new Headers({
      "content-type": "application/json",
      "cache-control": "no-store",
    });
    const origin = request.headers.get("origin");
    const allowed = (Deno.env.get("ALLOWED_ORIGINS") || "").split(",").filter(Boolean);
    if (origin && allowed.includes(origin)) {
      headers.set("access-control-allow-origin", origin);
      headers.set("vary", "Origin");
      headers.set(
        "access-control-allow-headers",
        "authorization,apikey,content-type,x-event-id,x-timestamp,x-signature",
      );
      headers.set("access-control-allow-methods", "POST,OPTIONS");
    }
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    try {
      if (request.method !== "POST") throw new ApiError(405, "method_not_allowed");
      if (origin && !allowed.includes(origin)) throw new ApiError(403, "origin_denied");
      return new Response(JSON.stringify(await handler(request)), { status: 200, headers });
    } catch (error) {
      const known = error instanceof ApiError;
      return new Response(JSON.stringify({ error: known ? error.code : "internal_error" }), {
        status: known ? error.status : 500,
        headers,
      });
    }
  };
}
