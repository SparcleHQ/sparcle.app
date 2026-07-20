interface Env {
  RESEND_API_KEY: string;
  TURNSTILE_SECRET_KEY: string;
  CONTACT_TO_EMAIL: string;
  CONTACT_FROM_EMAIL: string;
}

interface IntroPayload {
  name?: unknown;
  email?: unknown;
  company?: unknown;
  role?: unknown;
  budgetAuthority?: unknown;
  useCase?: unknown;
  timeframe?: unknown;
  consent?: unknown;
  partnerRef?: unknown;
  turnstileToken?: unknown;
}

const MAX_LEN = 1000;
const LONG_TEXT_LEN = 2000;
const USE_CASE_MIN = 80;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Free and personal mailbox providers. The engagement terms require the
// pre-call qualification to come from the attendee's own corporate address,
// so these are rejected server side. The client warns; this decides.
const FREE_EMAIL_DOMAINS = new Set([
  "gmail.com", "googlemail.com", "outlook.com", "outlook.co.uk", "hotmail.com",
  "hotmail.co.uk", "live.com", "live.co.uk", "msn.com", "yahoo.com", "yahoo.co.uk",
  "yahoo.co.in", "yahoo.ca", "yahoo.com.au", "ymail.com", "rocketmail.com",
  "icloud.com", "me.com", "mac.com", "aol.com", "proton.me", "protonmail.com",
  "pm.me", "gmx.com", "gmx.net", "mail.com", "zoho.com", "yandex.com",
  "yandex.ru", "qq.com", "163.com", "126.com", "naver.com", "tutanota.com",
  "tuta.io", "fastmail.com", "hushmail.com", "rediffmail.com", "inbox.com",
  "mail.ru", "web.de", "t-online.de", "free.fr", "orange.fr", "btinternet.com",
  "bigpond.com", "optusnet.com.au", "shaw.ca", "rogers.com", "sympatico.ca",
]);

const BUDGET_VALUES = new Set(["hold", "influence", "neither"]);
const TIMEFRAME_VALUES = new Set(["0-3", "3-6", "6-12", "exploratory"]);

const BUDGET_LABEL: Record<string, string> = {
  hold: "Holds budget for a purchase of this type",
  influence: "Influences budget, or reports directly to who does",
  neither: "Neither",
};
const TIMEFRAME_LABEL: Record<string, string> = {
  "0-3": "Next 0 to 3 months",
  "3-6": "3 to 6 months",
  "6-12": "6 to 12 months",
  exploratory: "Exploratory only, no timeframe",
};

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
  let payload: IntroPayload;
  try {
    payload = (await request.json()) as IntroPayload;
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const name = str(payload.name, 200);
  const email = str(payload.email, 200).toLowerCase();
  const company = str(payload.company, 200);
  const role = str(payload.role, 200);
  const budgetAuthority = str(payload.budgetAuthority, 40);
  const useCase = str(payload.useCase, LONG_TEXT_LEN);
  const timeframe = str(payload.timeframe, 40);
  const consent = payload.consent === true;
  const partnerRef = str(payload.partnerRef, 80);
  const token = str(payload.turnstileToken, 4096);

  if (!name || !company || !role || !useCase) {
    return json({ ok: false, error: "invalid_input" }, 400);
  }
  if (!email || !EMAIL_RE.test(email)) {
    return json({ ok: false, error: "invalid_email" }, 400);
  }
  if (!BUDGET_VALUES.has(budgetAuthority) || !TIMEFRAME_VALUES.has(timeframe)) {
    return json({ ok: false, error: "invalid_input" }, 400);
  }
  if (useCase.length < USE_CASE_MIN) {
    return json({ ok: false, error: "use_case_too_short" }, 400);
  }
  if (!consent) {
    return json({ ok: false, error: "consent_required" }, 400);
  }

  const domain = email.split("@")[1] ?? "";
  if (!domain || FREE_EMAIL_DOMAINS.has(domain)) {
    return json({ ok: false, error: "work_email_required" }, 400);
  }

  const ip = request.headers.get("CF-Connecting-IP") ?? "";
  const ua = request.headers.get("user-agent") ?? "";
  const submittedAt = new Date().toISOString();

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

  const qualifies = budgetAuthority !== "neither";
  const flag = qualifies ? "QUALIFIES" : "REVIEW: no budget authority stated";

  const subject =
    `[Sparcle] Discovery call request: ${company} (${name}) - ${flag}`;
  const text =
    `Discovery call request\n\n` +
    `Status:            ${flag}\n` +
    `Partner reference: ${partnerRef || "(none supplied)"}\n` +
    `Submitted at:      ${submittedAt}\n\n` +
    `Name:              ${name}\n` +
    `Work email:        ${email}\n` +
    `Email domain:      ${domain}\n` +
    `Company:           ${company}\n` +
    `Job title:         ${role}\n` +
    `Budget authority:  ${BUDGET_LABEL[budgetAuthority]}\n` +
    `Timeframe:         ${TIMEFRAME_LABEL[timeframe]}\n` +
    `Consent to contact: yes, given at ${submittedAt}\n\n` +
    `Business problem or use case:\n${useCase}\n\n` +
    `IP:         ${ip}\n` +
    `User-Agent: ${ua}\n\n` +
    `Retain this record. It evidences the pre-call qualification and the\n` +
    `express consent to be contacted.\n`;
  const html =
    `<p><strong>Discovery call request</strong> &mdash; ${escapeHtml(flag)}</p>` +
    `<table cellpadding="6" style="border-collapse:collapse">` +
    `<tr><td><b>Partner reference</b></td><td>${escapeHtml(partnerRef || "(none supplied)")}</td></tr>` +
    `<tr><td><b>Submitted at</b></td><td>${escapeHtml(submittedAt)}</td></tr>` +
    `<tr><td><b>Name</b></td><td>${escapeHtml(name)}</td></tr>` +
    `<tr><td><b>Work email</b></td><td><a href="mailto:${escapeHtml(email)}">${escapeHtml(email)}</a></td></tr>` +
    `<tr><td><b>Email domain</b></td><td>${escapeHtml(domain)}</td></tr>` +
    `<tr><td><b>Company</b></td><td>${escapeHtml(company)}</td></tr>` +
    `<tr><td><b>Job title</b></td><td>${escapeHtml(role)}</td></tr>` +
    `<tr><td><b>Budget authority</b></td><td>${escapeHtml(BUDGET_LABEL[budgetAuthority])}</td></tr>` +
    `<tr><td><b>Timeframe</b></td><td>${escapeHtml(TIMEFRAME_LABEL[timeframe])}</td></tr>` +
    `<tr><td><b>Consent to contact</b></td><td>Yes, given at ${escapeHtml(submittedAt)}</td></tr>` +
    `</table>` +
    `<h4>Business problem or use case</h4>` +
    `<p>${escapeHtml(useCase).replace(/\n/g, "<br>")}</p>` +
    `<p style="font-size:12px;color:#666">IP: ${escapeHtml(ip)}<br>User-Agent: ${escapeHtml(ua)}</p>` +
    `<p style="font-size:12px;color:#666">Retain this record. It evidences the pre-call ` +
    `qualification and the express consent to be contacted.</p>`;

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

  const first = name.split(" ")[0] || "there";
  const replySubject = "Sparcle: your discovery call request";
  const replyText =
    `Hi ${first},\n\n` +
    `Thanks for the detail. We have what we need to make the call useful ` +
    `rather than generic.\n\n` +
    `Pick a slot using the link on the confirmation page, or reply to this ` +
    `email and we will find a time. The call runs about 30 to 45 minutes and ` +
    `is a live product walkthrough against the use case you described.\n\n` +
    `You asked to be contacted about this on ${submittedAt}. You can withdraw ` +
    `that at any time by replying with the word unsubscribe, and we will stop.\n\n` +
    `Sparcle Team\nbolt@sparcle.app\n`;
  const replyHtml =
    `<p>Hi ${escapeHtml(first)},</p>` +
    `<p>Thanks for the detail. We have what we need to make the call useful ` +
    `rather than generic.</p>` +
    `<p>Pick a slot using the link on the confirmation page, or reply to this ` +
    `email and we will find a time. The call runs about 30 to 45 minutes and ` +
    `is a live product walkthrough against the use case you described.</p>` +
    `<p style="font-size:13px;color:#555">You asked to be contacted about this on ` +
    `${escapeHtml(submittedAt)}. You can withdraw that at any time by replying ` +
    `with the word unsubscribe, and we will stop.</p>` +
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
    console.warn("partner-intro auto-reply failed", await replyResp.text());
  }

  return json({ ok: true });
};
