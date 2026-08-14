export type AuthEmailUser = {
  email: string;
  new_email?: string;
};

export type AuthEmailData = {
  token?: string;
  token_hash?: string;
  redirect_to?: string;
  email_action_type: string;
  site_url?: string;
  token_new?: string;
  token_hash_new?: string;
  old_email?: string;
  old_phone?: string;
  provider?: string;
  factor_type?: string;
};

export type AuthEmailPayload = {
  user: AuthEmailUser;
  email_data: AuthEmailData;
};

export type OutgoingEmail = {
  to: string;
  subject: string;
  html: string;
  text: string;
};

export class InvalidHookPayloadError extends Error {}

const SUPPORT_EMAIL = "support@maplov.ca";

function required(value: string | undefined, field: string): string {
  const normalized = value?.trim();
  if (!normalized) {
    throw new InvalidHookPayloadError(`Missing required field: ${field}`);
  }
  return normalized;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function verifyLink(
  supabaseUrl: string,
  tokenHash: string,
  actionType: string,
  redirectTo: string,
): string {
  const url = new URL("/auth/v1/verify", supabaseUrl);
  url.searchParams.set("token", tokenHash);
  url.searchParams.set("type", actionType);
  url.searchParams.set("redirect_to", redirectTo);
  return url.toString();
}

function layout(params: {
  heading: string;
  intro: string;
  buttonLabel?: string;
  buttonUrl?: string;
  code?: string;
  warning?: string;
}): string {
  const button = params.buttonLabel && params.buttonUrl
    ? `<p style="margin:28px 0"><a href="${escapeHtml(params.buttonUrl)}" style="display:inline-block;background:#ff5964;color:#ffffff;text-decoration:none;padding:14px 24px;border-radius:999px;font-weight:700">${escapeHtml(params.buttonLabel)}</a></p>`
    : "";
  const code = params.code
    ? `<div style="margin:28px 0;padding:18px 22px;background:#fff4f5;border:1px solid #ffd7da;border-radius:12px;font-size:30px;font-weight:700;letter-spacing:7px;color:#e83e62;text-align:center">${escapeHtml(params.code)}</div>`
    : "";
  const warning = params.warning
    ? `<p style="font-size:13px;color:#6f6267;line-height:20px">${escapeHtml(params.warning)}</p>`
    : "";

  return `<!doctype html>
<html lang="en">
  <body style="margin:0;background:#fff5f6;font-family:Arial,Helvetica,sans-serif;color:#2a2024">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
      <tr><td align="center" style="padding:32px 16px">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px">
          <tr><td style="padding:32px">
            <h1 style="margin:0 0 8px;color:#ff5964">MapLov</h1>
            <h2 style="margin:20px 0 14px;color:#2a2024">${escapeHtml(params.heading)}</h2>
            <p style="font-size:16px;line-height:25px">${escapeHtml(params.intro)}</p>
            ${button}
            ${code}
            ${warning}
            <hr style="border:0;border-top:1px solid #f1dfe3;margin:28px 0">
            <p style="font-size:13px;color:#6f6267">Need help? <a href="mailto:${SUPPORT_EMAIL}" style="color:#e83e62">${SUPPORT_EMAIL}</a></p>
            <p style="font-size:12px;color:#998d91">© 2026 MapLov. All rights reserved.</p>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}

function codeEmail(params: {
  to: string;
  subject: string;
  heading: string;
  intro: string;
  code: string;
  warning: string;
}): OutgoingEmail {
  return {
    to: params.to,
    subject: params.subject,
    html: layout(params),
    text: `${params.heading}\n\n${params.intro}\n\nCode: ${params.code}\n\n${params.warning}`,
  };
}

function linkEmail(params: {
  to: string;
  subject: string;
  heading: string;
  intro: string;
  buttonLabel: string;
  buttonUrl: string;
  code?: string;
  warning: string;
}): OutgoingEmail {
  const codeText = params.code ? `\n\nOne-time code: ${params.code}` : "";
  return {
    to: params.to,
    subject: params.subject,
    html: layout(params),
    text:
      `${params.heading}\n\n${params.intro}\n\n${params.buttonUrl}${codeText}\n\n${params.warning}`,
  };
}

function notificationEmail(params: {
  to: string;
  subject: string;
  heading: string;
  intro: string;
}): OutgoingEmail {
  const warning =
    `If you did not make this change, reset your password and contact ${SUPPORT_EMAIL} immediately.`;
  return {
    to: params.to,
    subject: params.subject,
    html: layout({
      heading: params.heading,
      intro: params.intro,
      warning,
    }),
    text: `${params.heading}\n\n${params.intro}\n\n${warning}`,
  };
}

function emailChangeMessages(
  user: AuthEmailUser,
  data: AuthEmailData,
  supabaseUrl: string,
): OutgoingEmail[] {
  const currentEmail = required(user.email, "user.email");
  const newEmail = required(user.new_email, "user.new_email");
  const redirectTo = required(data.redirect_to, "email_data.redirect_to");
  const tokenHash = required(data.token_hash, "email_data.token_hash");

  // Secure email change sends two messages. Supabase's hash field names are
  // intentionally reversed for backward compatibility.
  if (data.token_new?.trim() && data.token_hash_new?.trim()) {
    const currentToken = required(data.token, "email_data.token");
    const newToken = required(data.token_new, "email_data.token_new");
    const currentHash = required(
      data.token_hash_new,
      "email_data.token_hash_new",
    );

    return [
      linkEmail({
        to: currentEmail,
        subject: "Confirm your MapLov email change",
        heading: "Confirm your email change",
        intro: `Approve changing your MapLov email address to ${newEmail}.`,
        buttonLabel: "Approve email change",
        buttonUrl: verifyLink(
          supabaseUrl,
          currentHash,
          "email_change",
          redirectTo,
        ),
        code: currentToken,
        warning: "If you did not request this change, do not approve it.",
      }),
      linkEmail({
        to: newEmail,
        subject: "Confirm your new MapLov email address",
        heading: "Confirm your new email",
        intro: "Confirm this address as the new email for your MapLov account.",
        buttonLabel: "Confirm new email",
        buttonUrl: verifyLink(
          supabaseUrl,
          tokenHash,
          "email_change",
          redirectTo,
        ),
        code: newToken,
        warning: "If you did not request this change, ignore this email.",
      }),
    ];
  }

  // Non-secure email change sends one message to the new address. Depending
  // on the Auth version, its OTP may be present in token or token_new.
  const token = required(data.token_new || data.token, "email change token");
  return [
    linkEmail({
      to: newEmail,
      subject: "Confirm your new MapLov email address",
      heading: "Confirm your new email",
      intro: "Confirm this address as the new email for your MapLov account.",
      buttonLabel: "Confirm new email",
      buttonUrl: verifyLink(
        supabaseUrl,
        tokenHash,
        "email_change",
        redirectTo,
      ),
      code: token,
      warning: "If you did not request this change, ignore this email.",
    }),
  ];
}

export function buildAuthEmails(
  payload: AuthEmailPayload,
  supabaseUrl: string,
): OutgoingEmail[] {
  if (!payload || typeof payload !== "object" || !payload.user ||
    !payload.email_data) {
    throw new InvalidHookPayloadError("Invalid Send Email Hook payload");
  }

  const userEmail = required(payload.user.email, "user.email");
  const data = payload.email_data;
  const action = required(
    data.email_action_type,
    "email_data.email_action_type",
  );

  switch (action) {
    case "signup":
      return [
        codeEmail({
          to: userEmail,
          subject: "Welcome to MapLov - Verify your email",
          heading: "Verify your email address",
          intro: "Enter this one-time code in the MapLov application:",
          code: required(data.token, "email_data.token"),
          warning:
            "This code expires in one hour. If you did not create a MapLov account, ignore this email.",
        }),
      ];

    case "recovery": {
      const token = required(data.token, "email_data.token");
      const link = verifyLink(
        supabaseUrl,
        required(data.token_hash, "email_data.token_hash"),
        action,
        required(data.redirect_to, "email_data.redirect_to"),
      );
      return [
        linkEmail({
          to: userEmail,
          subject: "Reset your MapLov password",
          heading: "Reset your password",
          intro: "Open MapLov securely to choose a new password.",
          buttonLabel: "Reset my password",
          buttonUrl: link,
          code: token,
          warning:
            "This link expires in one hour. If you did not request a password reset, ignore this email.",
        }),
      ];
    }

    case "magiclink":
    case "invite": {
      const isInvite = action === "invite";
      const link = verifyLink(
        supabaseUrl,
        required(data.token_hash, "email_data.token_hash"),
        action,
        required(data.redirect_to, "email_data.redirect_to"),
      );
      return [
        linkEmail({
          to: userEmail,
          subject: isInvite
            ? "You are invited to MapLov"
            : "Your secure MapLov sign-in link",
          heading: isInvite ? "Join MapLov" : "Sign in to MapLov",
          intro: isInvite
            ? "Use this secure link to accept your invitation."
            : "Use this secure link to sign in to your account.",
          buttonLabel: isInvite ? "Accept invitation" : "Sign in securely",
          buttonUrl: link,
          code: data.token?.trim() || undefined,
          warning:
            "This link is time-limited and can only be used once. If you did not request it, ignore this email.",
        }),
      ];
    }

    case "email_change":
      return emailChangeMessages(payload.user, data, supabaseUrl);

    case "reauthentication":
      return [
        codeEmail({
          to: userEmail,
          subject: "Confirm your MapLov security action",
          heading: "Confirm it is you",
          intro: "Enter this one-time code in MapLov to continue:",
          code: required(data.token, "email_data.token"),
          warning:
            "If you did not initiate this security action, change your password immediately.",
        }),
      ];

    case "password_changed":
      return [
        notificationEmail({
          to: userEmail,
          subject: "Your MapLov password was changed",
          heading: "Password changed",
          intro: "The password for your MapLov account was recently changed.",
        }),
      ];

    case "email_changed":
      return [
        notificationEmail({
          to: userEmail,
          subject: "Your MapLov email was changed",
          heading: "Email address changed",
          intro: "The email address for your MapLov account was recently changed.",
        }),
      ];

    case "phone_changed":
      return [
        notificationEmail({
          to: userEmail,
          subject: "Your MapLov phone number was changed",
          heading: "Phone number changed",
          intro: "The phone number for your MapLov account was recently changed.",
        }),
      ];

    case "identity_linked":
    case "identity_unlinked": {
      const linked = action === "identity_linked";
      const provider = data.provider?.trim();
      return [
        notificationEmail({
          to: userEmail,
          subject: linked
            ? "A sign-in method was linked to MapLov"
            : "A sign-in method was removed from MapLov",
          heading: linked ? "Sign-in method linked" : "Sign-in method removed",
          intro: provider
            ? `${provider} was ${linked ? "linked to" : "removed from"} your MapLov account.`
            : `A sign-in method was ${linked ? "linked to" : "removed from"} your MapLov account.`,
        }),
      ];
    }

    case "mfa_factor_enrolled":
    case "mfa_factor_unenrolled": {
      const enrolled = action === "mfa_factor_enrolled";
      return [
        notificationEmail({
          to: userEmail,
          subject: enrolled
            ? "A verification method was added to MapLov"
            : "A verification method was removed from MapLov",
          heading: enrolled
            ? "Verification method added"
            : "Verification method removed",
          intro:
            `A verification method was ${enrolled ? "added to" : "removed from"} your MapLov account.`,
        }),
      ];
    }

    default:
      throw new InvalidHookPayloadError(
        `Unsupported email action type: ${action}`,
      );
  }
}
