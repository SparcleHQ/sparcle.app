interface Env {
  RESEND_API_KEY: string;
  TURNSTILE_SECRET_KEY: string;
  CONTACT_TO_EMAIL: string;
  CONTACT_FROM_EMAIL: string;
}

interface ApplicationPayload {
  name?: unknown;
  email?: unknown;
  company?: unknown;
  role?: unknown;
  sector?: unknown;
  companySize?: unknown;
  aiStage?: unknown;
  primaryUseCase?: unknown;
  pilotBudgetTimeline?: unknown;
  engineeringAvailability?: unknown;
  whyGoodFit?: unknown;
  turnstileToken?: unknown;
}

const MAX_LEN = 1000;
const LONG_TEXT_LEN = 2000;
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
  let payload: ApplicationPayload;
  try {
    payload = (await request.json()) as ApplicationPayload;
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const name = str(payload.name, 200);
  const email = str(payload.email, 200);
  const company = str(payload.company, 200);
  const role = str(payload.role, 200);
  const sector = str(payload.sector, 100);
  const companySize = str(payload.companySize, 100);
  const aiStage = str(payload.aiStage, 100);
  const primaryUseCase = str(payload.primaryUseCase, LONG_TEXT_LEN);
  const pilotBudgetTimeline = str(payload.pilotBudgetTimeline, 100);
  const engineeringAvailability = str(payload.engineeringAvailability, 100);
  const whyGoodFit = str(payload.whyGoodFit, LONG_TEXT_LEN);
  const token = str(payload.turnstileToken, 4096);

  if (!name || !email || !EMAIL_RE.test(email) || !company || !primaryUseCase) {
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

  // Internal notification with the full application
  const subject = `[Sparcle] Design Partner application: ${company} (${name})`;
  const text =
    `New Design Partner application\n\n` +
    `Name:                  ${name}\n` +
    `Email:                 ${email}\n` +
    `Company:               ${company}\n` +
    `Role:                  ${role}\n` +
    `Sector:                ${sector}\n` +
    `Company size:          ${companySize}\n` +
    `AI initiative stage:   ${aiStage}\n` +
    `Pilot budget timeline: ${pilotBudgetTimeline}\n` +
    `Engineering avail:     ${engineeringAvailability}\n\n` +
    `Primary use case:\n${primaryUseCase}\n\n` +
    `Why a good fit:\n${whyGoodFit}\n\n` +
    `IP:         ${ip}\n` +
    `User-Agent: ${ua}\n`;
  const html =
    `<p><strong>New Design Partner application</strong></p>` +
    `<table cellpadding="6" style="border-collapse:collapse">` +
    `<tr><td><b>Name</b></td><td>${escapeHtml(name)}</td></tr>` +
    `<tr><td><b>Email</b></td><td><a href="mailto:${escapeHtml(email)}">${escapeHtml(email)}</a></td></tr>` +
    `<tr><td><b>Company</b></td><td>${escapeHtml(company)}</td></tr>` +
    `<tr><td><b>Role</b></td><td>${escapeHtml(role)}</td></tr>` +
    `<tr><td><b>Sector</b></td><td>${escapeHtml(sector)}</td></tr>` +
    `<tr><td><b>Company size</b></td><td>${escapeHtml(companySize)}</td></tr>` +
    `<tr><td><b>AI initiative stage</b></td><td>${escapeHtml(aiStage)}</td></tr>` +
    `<tr><td><b>Pilot budget timeline</b></td><td>${escapeHtml(pilotBudgetTimeline)}</td></tr>` +
    `<tr><td><b>Engineering availability</b></td><td>${escapeHtml(engineeringAvailability)}</td></tr>` +
    `</table>` +
    `<h4>Primary use case</h4><p>${escapeHtml(primaryUseCase).replace(/\n/g, "<br>")}</p>` +
    `<h4>Why a good fit</h4><p>${escapeHtml(whyGoodFit).replace(/\n/g, "<br>")}</p>` +
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

  // Auto-reply to the applicant
  const replySubject = "Sparcle Design Partner Program: application received";
  const replyText =
    `Hi ${name.split(" ")[0] || "there"},\n\n` +
    `Thanks for applying to the Sparcle Design Partner Program. We received ` +
    `your application and will review it within a week.\n\n` +
    `The cohort is capped at five to seven partners and we read every ` +
    `application carefully. We'll respond yes or no, regardless of outcome, ` +
    `inside seven days.\n\n` +
    `If your application moves forward, the next step is a 30-minute call to ` +
    `go through scope, constraints, and what design partnership actually ` +
    `means in practice. No slides.\n\n` +
    `Sparcle Team\nbolt@sparcle.app\n`;
  const replyHtml =
    `<p>Hi ${escapeHtml(name.split(" ")[0] || "there")},</p>` +
    `<p>Thanks for applying to the Sparcle Design Partner Program. We ` +
    `received your application and will review it within a week.</p>` +
    `<p>The cohort is capped at five to seven partners and we read every ` +
    `application carefully. We'll respond yes or no, regardless of ` +
    `outcome, inside seven days.</p>` +
    `<p>If your application moves forward, the next step is a 30-minute ` +
    `call to go through scope, constraints, and what design partnership ` +
    `actually means in practice. No slides.</p>` +
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
  if (!replyResp.ok) {
    console.warn("design-partners auto-reply failed", await replyResp.text());
  }

  return json({ ok: true });
};
