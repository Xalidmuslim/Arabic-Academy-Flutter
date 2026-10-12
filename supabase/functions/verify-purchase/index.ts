import { ApiError, readBody, serve, stringField } from "../_shared/http.ts";
import { authenticate, productKind, rpc } from "../_shared/supabase.ts";
import { verifyApple, verifyGoogle } from "../_shared/stores.ts";
export const handler = serve(async (request) => {
  const auth = await authenticate(request),
    body = await readBody(request),
    provider = stringField(body, "provider");
  let verified;
  if (provider === "apple") {
    verified = await verifyApple(auth.userId, stringField(body, "transaction_id", 128));
  } else if (provider === "google") {
    const id = stringField(body, "product_id", 256), kind = await productKind("google", id);
    if (body.kind !== undefined && body.kind !== kind) {
      throw new ApiError(400, "product_kind_mismatch");
    }
    verified = await verifyGoogle(auth.userId, stringField(body, "purchase_token", 4096), id, kind);
  } else throw new ApiError(400, "invalid_provider");
  const kind = await productKind(verified.provider, verified.productId);
  if ((kind === "subscription") !== (verified.expiresAt !== null)) {
    throw new ApiError(403, "product_kind_mismatch");
  }
  const purchase = await rpc("apply_verified_purchase", {
    p_user_id: auth.userId,
    p_provider: verified.provider,
    p_transaction_id: verified.transactionId,
    p_product_external_id: verified.productId,
    p_account_binding: verified.accountBinding,
    p_purchased_at: verified.purchasedAt,
    p_expires_at: verified.expiresAt,
    p_payload: verified.evidence,
  });
  return { purchase };
});
if (import.meta.main) Deno.serve(handler);
