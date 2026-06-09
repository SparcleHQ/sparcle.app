interface Env {
  RESEND_API_KEY: string;
  TURNSTILE_SECRET_KEY: string;
  CONTACT_TO_EMAIL: string;
  CONTACT_FROM_EMAIL: string;
}

interface ChecklistPayload {
  name?: unknown;
  email?: unknown;
  company?: unknown;
  role?: unknown;
  sector?: unknown;
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
  let payload: ChecklistPayload;
  try {
    payload = (await request.json()) as ChecklistPayload;
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const name = str(payload.name, 200);
  const email = str(payload.email, 200);
  const company = str(payload.company, 200);
  const role = str(payload.role, 200);
  const sector = str(payload.sector, 100);
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

  // Internal notification to the team inbox
  const subject = `[Sparcle] Vendor Checklist download by ${name}${company ? " (" + company + ")" : ""}`;
  const text =
    `New vendor checklist download\n\n` +
    `Name:    ${name}\n` +
    `Email:   ${email}\n` +
    `Company: ${company}\n` +
    `Role:    ${role}\n` +
    `Sector:  ${sector}\n\n` +
    `IP:         ${ip}\n` +
    `User-Agent: ${ua}\n`;
  const html =
    `<p><strong>New vendor checklist download</strong></p>` +
    `<table cellpadding="6" style="border-collapse:collapse">` +
    `<tr><td><b>Name</b></td><td>${escapeHtml(name)}</td></tr>` +
    `<tr><td><b>Email</b></td><td><a href="mailto:${escapeHtml(email)}">${escapeHtml(email)}</a></td></tr>` +
    `<tr><td><b>Company</b></td><td>${escapeHtml(company)}</td></tr>` +
    `<tr><td><b>Role</b></td><td>${escapeHtml(role)}</td></tr>` +
    `<tr><td><b>Sector</b></td><td>${escapeHtml(sector)}</td></tr>` +
    `</table>` +
    `<p style="font-size:12px;color:#666">IP: ${escapeHtml(ip)}<br>User-Agent: ${escapeHtml(ua)}</p>`;

  const notify = fetch("https://api.resend.com/emails", {
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

  // Auto-reply to the requester with the checklist link.
  const checklistUrl = "https://sparcle.app/docs/ai-vendor-checklist";
  const replySubject = "Your AI Agent Vendor Evaluation Checklist link";
  const replyText =
    `Hi ${name.split(" ")[0] || "there"},\n\n` +
    `Thanks for requesting the checklist. The full content is here:\n\n` +
    `${checklistUrl}\n\n` +
    `The page is printable, and renders cleanly to PDF from any browser ` +
    `("File > Print > Save as PDF"). Feel free to share it with your team.\n\n` +
    `If any of the fifteen questions feel wrong, missing, or worded for the ` +
    `wrong sector, reply to this email. We update the list based on what ` +
    `comes back from people actually using it in a vendor evaluation.\n\n` +
    `Sparcle Team\nbolt@sparcle.app\n`;
  const replyHtml =
    `<p>Hi ${escapeHtml(name.split(" ")[0] || "there")},</p>` +
    `<p>Thanks for requesting the checklist. The full content is here:</p>` +
    `<p><a href="${checklistUrl}">${checklistUrl}</a></p>` +
    `<p>The page is printable, and renders cleanly to PDF from any browser ` +
    `("File &gt; Print &gt; Save as PDF"). Feel free to share it with your team.</p>` +
    `<p>If any of the fifteen questions feel wrong, missing, or worded for ` +
    `the wrong sector, reply to this email. We update the list based on what ` +
    `comes back from people actually using it in a vendor evaluation.</p>` +
    `<p>Sparcle Team<br><a href="mailto:bolt@sparcle.app">bolt@sparcle.app</a></p>`;

  const autoReply = fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: env.CONTACT_FROM_EMAIL,
      to: [email],
      subject: replySubject,
      text: replyText,
      html: replyHtml,
    }),
  });

  const [notifyResp, replyResp] = await Promise.all([notify, autoReply]);

  if (!notifyResp.ok) {
    const detail = await notifyResp.text();
    return json({ ok: false, error: "notify_failed", detail }, 502);
  }
  // If the auto-reply fails, the user has already gotten the success
  // response on the page (with the link visible). Log it but don't fail
  // the request.
  if (!replyResp.ok) {
    console.warn("checklist auto-reply failed", await replyResp.text());
  }

  return json({ ok: true });
};
