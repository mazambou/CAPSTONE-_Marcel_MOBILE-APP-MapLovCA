import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  adminClient,
  requiredEnv,
  stripeCatalog,
  StripeCatalogEntry,
  stripePriceByLookupKey,
  stripeRequest,
  validStripePrice,
} from "../_shared/external_billing.ts";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { status, headers });
}

async function requireAdmin(request: Request): Promise<string> {
  const authorization = request.headers.get("Authorization");
  if (!authorization) throw new Error("Authentication required");
  const client = createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    { global: { headers: { Authorization: authorization } } },
  );
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) throw new Error("Authentication required");
  const { data: profile, error: profileError } = await adminClient()
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  if (profileError || profile?.role !== "admin") {
    throw new Error("Administrator access required");
  }
  return user.id;
}

async function stripeProducts(): Promise<Record<string, any>[]> {
  const response = await stripeRequest("/v1/products?active=true&limit=100");
  const body = await response.json();
  if (!response.ok || !Array.isArray(body.data)) {
    throw new Error(`Stripe product lookup failed (${response.status})`);
  }
  return body.data;
}

async function createProduct(entry: StripeCatalogEntry) {
  const form = new URLSearchParams({
    name: entry.name,
    description: entry.description,
    "metadata[maplov_product_id]": entry.productId,
  });
  const response = await stripeRequest("/v1/products", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": `maplov-product-${entry.productId}-v1`,
    },
    body: form,
  });
  const product = await response.json();
  if (!response.ok || typeof product.id !== "string") {
    throw new Error(`Stripe product creation failed (${response.status})`);
  }
  return product;
}

async function createPrice(
  entry: StripeCatalogEntry,
  productId: string,
  replacing: boolean,
) {
  const form = new URLSearchParams({
    product: productId,
    unit_amount: String(entry.amountMinor),
    currency: "cad",
    lookup_key: entry.productId,
    "metadata[maplov_product_id]": entry.productId,
  });
  if (entry.interval) form.set("recurring[interval]", entry.interval);
  if (replacing) form.set("transfer_lookup_key", "true");
  const response = await stripeRequest("/v1/prices", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key":
        `maplov-price-${entry.productId}-${entry.amountMinor}-${
          entry.interval ?? "once"
        }`,
    },
    body: form,
  });
  const price = await response.json();
  if (!response.ok || typeof price.id !== "string") {
    throw new Error(`Stripe price creation failed (${response.status})`);
  }
  return price;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers });
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const adminId = await requireAdmin(request);
    const products = await stripeProducts();
    const synchronized: Record<string, unknown>[] = [];

    for (const entry of stripeCatalog) {
      const currentPrice = await stripePriceByLookupKey(entry.productId);
      if (currentPrice && validStripePrice(currentPrice, entry)) {
        synchronized.push({
          productId: entry.productId,
          stripeProductId: currentPrice.product,
          stripePriceId: currentPrice.id,
          status: "unchanged",
        });
        continue;
      }

      const existingProduct = currentPrice?.product
        ? products.find((item) => item.id === currentPrice.product)
        : products.find(
          (item) => item.metadata?.maplov_product_id === entry.productId,
        );
      const product = existingProduct ?? await createProduct(entry);
      const price = await createPrice(
        entry,
        String(product.id),
        currentPrice !== null,
      );
      if (currentPrice?.id) {
        const archive = new URLSearchParams({ active: "false" });
        const archiveResponse = await stripeRequest(
          `/v1/prices/${encodeURIComponent(String(currentPrice.id))}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: archive,
          },
        );
        if (!archiveResponse.ok) {
          throw new Error(
            `Old Stripe price could not be archived (${archiveResponse.status})`,
          );
        }
      }
      synchronized.push({
        productId: entry.productId,
        stripeProductId: product.id,
        stripePriceId: price.id,
        status: currentPrice ? "replaced" : "created",
      });
    }

    await adminClient().from("admin_actions").insert({
      admin_id: adminId,
      action: "stripe_catalog_synchronized",
      target_type: "billing_catalog",
      metadata: { products: synchronized },
    });
    return json({ products: synchronized });
  } catch (error) {
    console.error("Stripe catalog synchronization failed", error);
    const message = error instanceof Error ? error.message : "Unknown error";
    const forbidden = message.includes("Authentication") ||
      message.includes("Administrator");
    return json(
      { error: forbidden ? message : "Unable to synchronize Stripe catalog" },
      forbidden ? 403 : 500,
    );
  }
});
