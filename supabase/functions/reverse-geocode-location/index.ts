const canonicalOrigins = new Set([
  "https://maplov.ca",
  "https://www.maplov.ca",
]);

function allowedOrigin(request: Request): string | null {
  const origin = request.headers.get("Origin")?.trim();
  if (!origin) return null;
  const configured = (Deno.env.get("EXTERNAL_CHECKOUT_ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  if (canonicalOrigins.has(origin) || configured.includes(origin)) return origin;
  try {
    const url = new URL(origin);
    if (
      url.protocol === "http:" &&
      (url.hostname === "localhost" || url.hostname === "127.0.0.1")
    ) return origin;
  } catch (_) {
    // Invalid origins are rejected below.
  }
  return null;
}

function corsHeaders(origin: string): HeadersInit {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Cache-Control": "no-store",
    "Vary": "Origin",
  };
}

function json(
  body: Record<string, unknown>,
  status: number,
  origin: string,
): Response {
  return Response.json(body, { status, headers: corsHeaders(origin) });
}

function coordinate(value: unknown, minimum: number, maximum: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < minimum || parsed > maximum) {
    throw new Error("Invalid coordinates");
  }
  return parsed;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

Deno.serve(async (request) => {
  const origin = allowedOrigin(request);
  if (!origin) {
    return Response.json({ error: "This origin is not allowed" }, {
      status: 403,
      headers: { "Cache-Control": "no-store" },
    });
  }
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, origin);
  }

  try {
    const body = await request.json();
    const latitude = coordinate(body.latitude, -90, 90);
    const longitude = coordinate(body.longitude, -180, 180);
    const query = new URLSearchParams({
      format: "jsonv2",
      lat: latitude.toFixed(5),
      lon: longitude.toFixed(5),
      zoom: "10",
      addressdetails: "1",
      "accept-language": "en",
    });
    const response = await fetch(
      `https://nominatim.openstreetmap.org/reverse?${query.toString()}`,
      {
        headers: {
          "Accept": "application/json",
          "User-Agent": "MapLov/1.0 (https://maplov.ca)",
        },
      },
    );
    if (!response.ok) {
      throw new Error(`Reverse geocoder returned ${response.status}`);
    }
    const result = await response.json();
    const address = result?.address ?? {};
    const country = text(address.country);
    const countryCode = text(address.country_code).toUpperCase();
    const region = text(
      address.state ?? address.province ?? address.region ??
        address.state_district ?? address.county,
    );
    const city = text(
      address.city ?? address.town ?? address.village ?? address.municipality ??
        address.county ?? region,
    );
    if (!country || countryCode.length !== 2) {
      return json({ error: "Residence country was not found" }, 422, origin);
    }
    return json({ country, countryCode, region, city }, 200, origin);
  } catch (error) {
    const invalid = error instanceof Error && error.message === "Invalid coordinates";
    console.error("Web residence reverse geocoding failed", error);
    return json(
      { error: invalid ? "Invalid coordinates" : "Unable to reverse geocode location" },
      invalid ? 400 : 502,
      origin,
    );
  }
});
