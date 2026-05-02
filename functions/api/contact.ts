interface Env {
  RESEND_API_KEY: string;
  TURNSTILE_SECRET_KEY: string;
  CONTACT_TO_EMAIL: string;
  CONTACT_FROM_EMAIL: string;
}

interface ContactPayload {
  name?: unknown;
  email?: unknown;
  company?: unknown;
  teamSize?: unknown;
  interest?: unknown;
  turnstileToken?: unknown;
}

const MAX_LEN = 1000;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const str = (v: unknown, max = MAX_LEN) =>
  (typeof v === "string" ? v : "").trim().slice(0, max);

const escapeHtml = (s: string) =>
  s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  let payload: ContactPayload;
  try {
    payload = (await request.json()) as ContactPayload;
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const name = str(payload.name);
  const email = str(payload.email);
  const company = str(payload.company);
  const teamSize = str(payload.teamSize, 64);
  const interest = str(payload.interest, 200) || "General Inquiry";
  const token = str(payload.turnstileToken, 4096);

  if (!name || !email || !EMAIL_RE.test(email)) {
    return json({ ok: false, error: "invalid_input" }, 400);
  }

  const ip = request.headers.get("CF-Connecting-IP") ?? "";
  const ua = request.headers.get("user-agent") ?? "";

  const verify = await fetch(
    "https://challenges.cloudflare.com/turnstile/v0/siteverify",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        secret: env.TURNSTILE_SECRET_KEY,
        response: token,
        remoteip: ip,
      }),
    },
  );
  const verifyData = (await verify.json()) as {
    success: boolean;
    "error-codes"?: string[];
  };
  if (!verifyData.success) {
    return json(
      { ok: false, error: "captcha_failed", codes: verifyData["error-codes"] ?? [] },
      400,
    );
  }

  const subject = `[Sparcle] ${interest} — ${company || name}`;
  const text =
    `New ${interest} from ${name}\n\n` +
    `Name:      ${name}\n` +
    `Email:     ${email}\n` +
    `Company:   ${company}\n` +
    `Team size: ${teamSize}\n` +
    `Interest:  ${interest}\n\n` +
    `IP:         ${ip}\n` +
    `User-Agent: ${ua}\n`;
  const html =
    `<p><strong>New ${escapeHtml(interest)} from ${escapeHtml(name)}</strong></p>` +
    `<table cellpadding="6" style="border-collapse:collapse">` +
    `<tr><td><b>Name</b></td><td>${escapeHtml(name)}</td></tr>` +
    `<tr><td><b>Email</b></td><td><a href="mailto:${escapeHtml(email)}">${escapeHtml(email)}</a></td></tr>` +
    `<tr><td><b>Company</b></td><td>${escapeHtml(company)}</td></tr>` +
    `<tr><td><b>Team size</b></td><td>${escapeHtml(teamSize)}</td></tr>` +
    `<tr><td><b>Interest</b></td><td>${escapeHtml(interest)}</td></tr>` +
    `</table>` +
    `<p style="font-size:12px;color:#666">IP: ${escapeHtml(ip)}<br>User-Agent: ${escapeHtml(ua)}</p>`;

  const resendResp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: env.CONTACT_FROM_EMAIL,
      to: [env.CONTACT_TO_EMAIL],
      reply_to: email,
      subject,
      text,
      html,
    }),
  });

  if (!resendResp.ok) {
    const detail = await resendResp.text();
    return json({ ok: false, error: "send_failed", detail }, 502);
  }

  return json({ ok: true });
};
