import {
  assertEquals,
  assertMatch,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildAuthEmails, InvalidHookPayloadError } from "./email_content.ts";

const supabaseUrl = "https://example.supabase.co";

Deno.test("signup sends the OTP to the current email", () => {
  const messages = buildAuthEmails({
    user: { email: "member@example.com" },
    email_data: { email_action_type: "signup", token: "123456" },
  }, supabaseUrl);

  assertEquals(messages.length, 1);
  assertEquals(messages[0].to, "member@example.com");
  assertMatch(messages[0].text, /123456/);
});

Deno.test("recovery contains a valid Supabase verification link", () => {
  const messages = buildAuthEmails({
    user: { email: "member@example.com" },
    email_data: {
      email_action_type: "recovery",
      token: "654321",
      token_hash: "recovery-hash",
      redirect_to: "https://maplov.ca/auth/callback",
    },
  }, supabaseUrl);

  const link = new URL(messages[0].text.split("\n").find((line) =>
    line.startsWith("https://")
  )!);
  assertEquals(link.origin, supabaseUrl);
  assertEquals(link.pathname, "/auth/v1/verify");
  assertEquals(link.searchParams.get("token"), "recovery-hash");
  assertEquals(link.searchParams.get("type"), "recovery");
  assertEquals(
    link.searchParams.get("redirect_to"),
    "https://maplov.ca/auth/callback",
  );
});

Deno.test("secure email change sends the documented hash pairs", () => {
  const messages = buildAuthEmails({
    user: {
      email: "old@example.com",
      new_email: "new@example.com",
    },
    email_data: {
      email_action_type: "email_change",
      token: "111111",
      token_hash: "new-address-hash",
      token_new: "222222",
      token_hash_new: "current-address-hash",
      redirect_to: "https://maplov.ca/auth/callback",
    },
  }, supabaseUrl);

  assertEquals(messages.length, 2);
  assertEquals(messages[0].to, "old@example.com");
  assertMatch(messages[0].text, /token=current-address-hash/);
  assertMatch(messages[0].text, /111111/);
  assertEquals(messages[1].to, "new@example.com");
  assertMatch(messages[1].text, /token=new-address-hash/);
  assertMatch(messages[1].text, /222222/);
});

Deno.test("security notifications never include an undefined token", () => {
  const messages = buildAuthEmails({
    user: { email: "member@example.com" },
    email_data: { email_action_type: "password_changed" },
  }, supabaseUrl);

  assertEquals(messages.length, 1);
  assertEquals(messages[0].text.includes("undefined"), false);
  assertEquals(messages[0].html.includes("undefined"), false);
});

Deno.test("unsupported action types are rejected", () => {
  assertThrows(
    () =>
      buildAuthEmails({
        user: { email: "member@example.com" },
        email_data: { email_action_type: "unexpected" },
      }, supabaseUrl),
    InvalidHookPayloadError,
  );
});
