import { importPKCS8, SignJWT } from "jose";
import { Environment, SignedDataVerifier } from "apple-store";
import { Buffer } from "node:buffer";
import { ApiError, checkedFetch, requiredEnv } from "./http.ts";
export interface VerifiedPurchase {
  provider: "apple" | "google";
  transactionId: string;
  productId: string;
  accountBinding: string;
  purchasedAt: string;
  expiresAt: string | null;
  evidence: Record<string, unknown>;
}
// Deployment configuration only; request bodies cannot opt into store sandbox verification.
function storeTestEnvironment(): boolean {
  const flag = Deno.env.get("STORE_TEST_ENVIRONMENT") || "false";
  if (
    !["true", "false"].includes(flag) ||
    (flag === "true" && Deno.env.get("DEPLOYMENT_ENVIRONMENT") !== "test")
  ) {
    throw new ApiError(503, "invalid_store_test_configuration");
  }
  return flag === "true";
}
const rejection = () => new ApiError(403, "purchase_not_verified");
function millis(value: unknown): string {
  if (typeof value !== "number" && typeof value !== "string") throw rejection();
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) throw rejection();
  const date = new Date(n);
  if (!Number.isFinite(date.getTime())) throw rejection();
  return date.toISOString();
}
export function validateAppleTransaction(
  t: Record<string, unknown>,
  userId: string,
  requestedId: string,
  bundleId: string,
): VerifiedPurchase {
  const sandbox = storeTestEnvironment();
  if (
    t.transactionId !== requestedId || t.bundleId !== bundleId ||
    t.environment !== (sandbox ? "Sandbox" : "Production") ||
    t.appAccountToken !== userId || t.revocationDate || t.inAppOwnershipType !== "PURCHASED" ||
    typeof t.productId !== "string" ||
    !["Non-Consumable", "Auto-Renewable Subscription"].includes(String(t.type))
  ) throw rejection();
  const subscription = t.type === "Auto-Renewable Subscription";
  const expires = subscription ? millis(t.expiresDate) : null;
  if (expires && Date.parse(expires) <= Date.now()) throw rejection();
  return {
    provider: "apple",
    transactionId: requestedId,
    productId: t.productId,
    accountBinding: userId,
    purchasedAt: millis(t.purchaseDate),
    expiresAt: expires,
    evidence: {
      transaction_id: requestedId,
      original_transaction_id: t.originalTransactionId,
      environment: t.environment,
      verified_by: "app_store_server_api_jws",
    },
  };
}
export async function verifyApple(
  userId: string,
  transactionId: string,
): Promise<VerifiedPurchase> {
  const sandbox = storeTestEnvironment();
  const bundle = requiredEnv("APPLE_BUNDLE_ID"),
    issuer = requiredEnv("APPLE_ISSUER_ID"),
    keyId = requiredEnv("APPLE_KEY_ID");
  const appleId = Number(requiredEnv("APPLE_APP_ID"));
  if (!Number.isSafeInteger(appleId) || appleId <= 0) {
    throw new ApiError(503, "invalid_apple_configuration");
  }
  let roots: Buffer[];
  try {
    const certs = JSON.parse(requiredEnv("APPLE_ROOT_CA_PEMS_JSON"));
    if (
      !Array.isArray(certs) || !certs.length ||
      certs.some((x: unknown) => typeof x !== "string" || !x.includes("BEGIN CERTIFICATE"))
    ) throw new Error();
    roots = certs.map((pem: string) => Buffer.from(pem));
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(503, "invalid_apple_configuration");
  }
  const signingKey = await importPKCS8(requiredEnv("APPLE_PRIVATE_KEY_P8"), "ES256");
  const token = await new SignJWT({ bid: bundle }).setProtectedHeader({
    alg: "ES256",
    kid: keyId,
    typ: "JWT",
  })
    .setIssuer(issuer).setAudience("appstoreconnect-v1").setIssuedAt().setExpirationTime("5m").sign(
      signingKey,
    );
  const response = await checkedFetch(
    `https://${
      sandbox ? "api.storekit-sandbox.itunes.apple.com" : "api.storekit.itunes.apple.com"
    }/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
    { headers: { authorization: `Bearer ${token}` } },
  );
  if (!response.ok) {
    throw response.status >= 500 ? new ApiError(502, "apple_unavailable") : rejection();
  }
  const data = await response.json();
  if (typeof data.signedTransactionInfo !== "string") throw rejection();
  // Verify Apple's certificate chain, environment, bundle and app ID; never decode-only.
  let transaction;
  try {
    transaction = await new SignedDataVerifier(
      roots,
      true,
      sandbox ? Environment.SANDBOX : Environment.PRODUCTION,
      bundle,
      appleId,
    )
      .verifyAndDecodeTransaction(data.signedTransactionInfo);
  } catch {
    throw rejection();
  }
  return validateAppleTransaction(
    transaction as unknown as Record<string, unknown>,
    userId,
    transactionId,
    bundle,
  );
}
async function googleToken(): Promise<string> {
  let account;
  try {
    account = JSON.parse(requiredEnv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"));
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(503, "invalid_google_configuration");
  }
  if (typeof account.client_email !== "string" || typeof account.private_key !== "string") {
    throw new ApiError(503, "invalid_google_configuration");
  }
  const key = await importPKCS8(account.private_key, "RS256");
  const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/androidpublisher" })
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
  if (!response.ok) throw new ApiError(502, "google_authentication_failed");
  const data = await response.json();
  if (typeof data.access_token !== "string") {
    throw new ApiError(502, "google_authentication_failed");
  }
  return data.access_token;
}
export async function googleClaimId(token: string): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(hash), (b) => b.toString(16).padStart(2, "0")).join("");
}
export function validateGooglePurchase(
  data: Record<string, unknown>,
  userId: string,
  productId: string,
  kind: "course" | "subscription",
  transactionId: string,
): VerifiedPurchase {
  const sandbox = storeTestEnvironment();
  let purchasedAt: string, expiresAt: string | null = null, accountBinding: unknown;
  if (kind === "course") {
    if (
      data.purchaseState !== 0 || data.consumptionState !== 0 ||
      (data.purchaseType !== undefined && !(sandbox && data.purchaseType === 0)) ||
      (data.quantity !== undefined && data.quantity !== 1)
    ) throw rejection();
    accountBinding = data.obfuscatedExternalAccountId;
    purchasedAt = millis(data.purchaseTimeMillis);
  } else {
    if (
      ![
        "SUBSCRIPTION_STATE_ACTIVE",
        "SUBSCRIPTION_STATE_CANCELED",
        "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      ].includes(String(data.subscriptionState)) || (data.testPurchase && !sandbox)
    ) {
      throw rejection();
    }
    const ids = data.externalAccountIdentifiers as Record<string, unknown> | undefined;
    accountBinding = ids?.obfuscatedExternalAccountId;
    const items = data.lineItems;
    // Fail closed for multi-product or unsupported deferred/prepaid/replacement flows.
    if (!Array.isArray(items) || items.length !== 1 || items[0].productId !== productId) {
      throw rejection();
    }
    if (
      typeof items[0].expiryTime !== "string" ||
      !Number.isFinite(Date.parse(items[0].expiryTime)) ||
      Date.parse(items[0].expiryTime) <= Date.now()
    ) throw rejection();
    expiresAt = new Date(items[0].expiryTime).toISOString();
    if (typeof data.startTime !== "string" || !Number.isFinite(Date.parse(data.startTime))) {
      throw rejection();
    }
    purchasedAt = new Date(data.startTime).toISOString();
  }
  if (accountBinding !== userId) throw rejection();
  return {
    provider: "google",
    transactionId,
    productId,
    accountBinding: userId,
    purchasedAt,
    expiresAt,
    evidence: {
      verified_by: "google_android_publisher",
      order_id: data.latestOrderId || data.orderId,
      acknowledged: true,
      environment: (data.testPurchase || data.purchaseType === 0) ? "test" : "production",
    },
  };
}
export async function verifyGoogle(
  userId: string,
  purchaseToken: string,
  productId: string,
  kind: "course" | "subscription",
): Promise<VerifiedPurchase> {
  storeTestEnvironment();
  const packageName = requiredEnv("GOOGLE_PLAY_PACKAGE_NAME"), token = await googleToken();
  const root = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
    encodeURIComponent(packageName)
  }/purchases`;
  const url = kind === "course"
    ? `${root}/products/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(purchaseToken)
    }`
    : `${root}/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const headers = { authorization: `Bearer ${token}`, "content-type": "application/json" };
  const response = await checkedFetch(url, { headers });
  if (!response.ok) {
    throw response.status >= 500 ? new ApiError(502, "google_unavailable") : rejection();
  }
  const data = await response.json();
  const verified = validateGooglePurchase(
    data,
    userId,
    productId,
    kind,
    await googleClaimId(purchaseToken),
  );
  const acknowledged = kind === "course"
    ? data.acknowledgementState === 1
    : data.acknowledgementState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED";
  if (!acknowledged) {
    // Only acknowledge after validating identity/state, before issuing an entitlement.
    const ack = await checkedFetch(
      `${root}/${kind === "course" ? "products" : "subscriptions"}/${
        encodeURIComponent(productId)
      }/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
      { method: "POST", headers, body: "{}" },
    );
    if (!ack.ok) throw new ApiError(502, "google_acknowledgement_failed");
  }
  return verified;
}
