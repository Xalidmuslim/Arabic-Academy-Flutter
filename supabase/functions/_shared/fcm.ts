import { importPKCS8, SignJWT } from "jose";
import { ApiError, checkedFetch, requiredEnv } from "./http.ts";
export async function fcmCredentials(): Promise<{ projectId: string; token: string }> {
  let account;
  try {
    account = JSON.parse(requiredEnv("FCM_SERVICE_ACCOUNT_JSON"));
  } catch (e) {
    if (e instanceof ApiError) throw e;
    throw new ApiError(503, "invalid_fcm_configuration");
  }
  if (
    typeof account.project_id !== "string" ||
    !account.project_id.match(/^[a-z0-9][a-z0-9-]{4,62}$/) ||
    typeof account.client_email !== "string" || typeof account.private_key !== "string"
  ) throw new ApiError(503, "invalid_fcm_configuration");
  let key;
  try {
    key = await importPKCS8(account.private_key, "RS256");
  } catch {
    throw new ApiError(503, "invalid_fcm_configuration");
  }
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" }).setIssuer(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token").setIssuedAt().setExpirationTime("5m").sign(
      key,
    );
  const response = await checkedFetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new ApiError(502, "fcm_authentication_failed");
  const data = await response.json();
  if (typeof data.access_token !== "string") throw new ApiError(502, "fcm_authentication_failed");
  return { projectId: account.project_id, token: data.access_token };
}
export async function sendFcm(
  credentials: { projectId: string; token: string },
  token: string,
  notification: { id: string; kind: string; body: Record<string, unknown> },
): Promise<boolean> {
  const title = typeof notification.body.title === "string"
    ? notification.body.title.slice(0, 200)
    : "Arabic Academy";
  const body = typeof notification.body.text === "string"
    ? notification.body.text.slice(0, 1000)
    : "";
  try {
    const response = await checkedFetch(
      `https://fcm.googleapis.com/v1/projects/${
        encodeURIComponent(credentials.projectId)
      }/messages:send`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${credentials.token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: { notification_id: notification.id, kind: notification.kind },
          },
        }),
      },
    );
    if (!response.ok) return false;
    const data = await response.json();
    return typeof data.name === "string" &&
      data.name.startsWith(`projects/${credentials.projectId}/messages/`);
  } catch {
    return false;
  }
}
