import { ApiError, checkedFetch, requiredEnv } from "./http.ts";
export interface AuthContext {
  userId: string;
  token: string;
  identity?: { id: string; phone: string | null; email: string | null; created_at: string | null };
}
function baseUrl(): string {
  const url = requiredEnv("SUPABASE_URL");
  if (!/^https:\/\//.test(url) && !/^http:\/\/(localhost|127\.0\.0\.1|kong)(:|\/)/.test(url)) {
    throw new ApiError(503, "invalid_supabase_url");
  }
  return url.replace(/\/$/, "");
}
export async function authenticate(request: Request): Promise<AuthContext> {
  const bearer = request.headers.get("authorization");
  if (!bearer?.startsWith("Bearer ") || bearer.length > 8192) {
    throw new ApiError(401, "authentication_required");
  }
  const token = bearer.slice(7);
  const response = await checkedFetch(`${baseUrl()}/auth/v1/user`, {
    headers: { apikey: requiredEnv("SUPABASE_ANON_KEY"), authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new ApiError(401, "invalid_access_token");
  const user = await response.json();
  if (typeof user.id !== "string") throw new ApiError(401, "invalid_access_token");
  return {
    userId: user.id,
    token,
    identity: {
      id: user.id,
      phone: typeof user.phone === "string" ? user.phone : null,
      email: typeof user.email === "string" ? user.email : null,
      created_at: typeof user.created_at === "string" ? user.created_at : null,
    },
  };
}
export async function rpc<T>(
  name: string,
  args: Record<string, unknown>,
  auth?: AuthContext,
): Promise<T> {
  const key = requiredEnv(auth ? "SUPABASE_ANON_KEY" : "SUPABASE_SERVICE_ROLE_KEY");
  const response = await checkedFetch(`${baseUrl()}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: key,
      authorization: `Bearer ${auth?.token || key}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(args),
  });
  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    const status = error.code === "54000"
      ? 429
      : error.code === "42501"
      ? 403
      : ["40001", "23505"].includes(error.code)
      ? 409
      : error.code === "55000"
      ? 503
      : 400;
    // SQL messages are controlled by these migrations; do not reflect arbitrary payload/detail fields.
    const code = /^[a-z_]+$/.test(error.message || "") ? error.message : "database_request_failed";
    throw new ApiError(status, code);
  }
  return response.json();
}
export async function productKind(
  provider: string,
  externalId: string,
): Promise<"course" | "subscription"> {
  const key = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const query = new URLSearchParams({
    select: "kind",
    provider: `eq.${provider}`,
    external_id: `eq.${externalId}`,
    active: "eq.true",
  });
  const res = await checkedFetch(`${baseUrl()}/rest/v1/products?${query}`, {
    headers: { apikey: key, authorization: `Bearer ${key}` },
  });
  if (!res.ok) throw new ApiError(503, "product_catalog_unavailable");
  const rows = await res.json();
  if (rows.length !== 1 || !["course", "subscription"].includes(rows[0].kind)) {
    throw new ApiError(403, "unknown_product");
  }
  return rows[0].kind;
}
export interface MediaAccess {
  media_id: string;
  bucket_id: string;
  object_path: string;
  mime_type: string;
  byte_size: number;
  expires_in: number;
}
export async function signMedia(access: MediaAccess): Promise<string> {
  const key = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const path = [access.bucket_id, ...access.object_path.split("/")].map(encodeURIComponent).join(
    "/",
  );
  const response = await checkedFetch(`${baseUrl()}/storage/v1/object/sign/${path}`, {
    method: "POST",
    headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify({ expiresIn: access.expires_in }),
  });
  if (!response.ok) throw new ApiError(502, "storage_unavailable");
  const result = await response.json();
  if (typeof result.signedURL !== "string" || !result.signedURL.startsWith("/object/sign/")) {
    throw new ApiError(502, "invalid_storage_response");
  }
  return `${baseUrl()}/storage/v1${result.signedURL}`;
}
export async function signUpload(access: MediaAccess): Promise<string> {
  const key = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const path = [access.bucket_id, ...access.object_path.split("/")].map(encodeURIComponent).join(
    "/",
  );
  const response = await checkedFetch(`${baseUrl()}/storage/v1/object/upload/sign/${path}`, {
    method: "POST",
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      "content-type": "application/json",
      "x-upsert": "false",
    },
    body: "{}",
  });
  if (!response.ok) throw new ApiError(502, "storage_unavailable");
  const data = await response.json();
  const token = typeof data.token === "string"
    ? data.token
    : typeof data.url === "string"
    ? new URL(data.url, baseUrl()).searchParams.get("token")
    : null;
  if (!token) throw new ApiError(502, "invalid_storage_response");
  return token;
}
export async function removeMedia(access: MediaAccess): Promise<void> {
  const key = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const response = await checkedFetch(
    `${baseUrl()}/storage/v1/object/${encodeURIComponent(access.bucket_id)}`,
    {
      method: "DELETE",
      headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({ prefixes: [access.object_path] }),
    },
  );
  if (!response.ok) throw new ApiError(502, "storage_unavailable");
}
export async function deleteAuthUser(userId: string): Promise<void> {
  const key = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const response = await checkedFetch(
    `${baseUrl()}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
    {
      method: "DELETE",
      headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({ should_soft_delete: false }),
    },
  );
  if (!response.ok) throw new ApiError(502, "account_delete_pending");
}
export async function removeMediaBatch(
  objects: { bucket_id: string; object_path: string }[],
): Promise<void> {
  const key = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const buckets = new Map<string, string[]>();
  for (const object of objects) {
    const paths = buckets.get(object.bucket_id) || [];
    paths.push(object.object_path);
    buckets.set(object.bucket_id, paths);
  }
  const requests: Promise<void>[] = [];
  for (const [bucket, paths] of buckets) {
    for (let i = 0; i < paths.length; i += 50) {
      requests.push((async () => {
        const res = await checkedFetch(
          `${baseUrl()}/storage/v1/object/${encodeURIComponent(bucket)}`,
          {
            method: "DELETE",
            headers: {
              apikey: key,
              authorization: `Bearer ${key}`,
              "content-type": "application/json",
            },
            body: JSON.stringify({ prefixes: paths.slice(i, i + 50) }),
          },
        );
        if (!res.ok) throw new ApiError(502, "storage_unavailable");
      })());
    }
  }
  await Promise.all(requests);
}
