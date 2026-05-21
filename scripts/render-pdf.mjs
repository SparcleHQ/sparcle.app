#!/usr/bin/env node
// Render a page from the local Astro dev server to a PDF using headless Chrome.
//
// Usage:
//   node scripts/render-pdf.mjs <url-path> <out.pdf>
//
// Example:
//   node scripts/render-pdf.mjs /docs/trial-quickstart public/docs/pdfs/trial-quickstart.pdf
//
// Requires:
//   - The Astro dev server running on http://localhost:4321 (run `npm run dev`
//     in another terminal first), OR a built+previewed copy on the same port.
//   - Google Chrome or Chromium installed on the host.
//
// Why no dependency on puppeteer/playwright: those bring ~150MB of postinstall
// downloads for a single one-shot operation. This script spawns the locally
// installed Chrome with --headless --print-to-pdf, which produces the same
// PDF output without any new npm baggage.

import { spawn } from "node:child_process";
import { existsSync, mkdirSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { platform } from "node:os";

const DEFAULT_BASE = process.env.PDF_BASE_URL || "http://localhost:4321";

const [, , pathArg, outArg] = process.argv;
if (!pathArg || !outArg) {
  console.error("usage: node scripts/render-pdf.mjs <url-path> <out.pdf>");
  console.error("example: node scripts/render-pdf.mjs /docs/trial-quickstart public/docs/pdfs/trial-quickstart.pdf");
  process.exit(2);
}

const url = pathArg.startsWith("http") ? pathArg : `${DEFAULT_BASE}${pathArg}`;
const outPath = resolve(process.cwd(), outArg);
mkdirSync(dirname(outPath), { recursive: true });

function locateChrome() {
  const candidates = [];
  if (process.env.CHROME_PATH) candidates.push(process.env.CHROME_PATH);

  const p = platform();
  if (p === "darwin") {
    candidates.push(
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
      "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    );
  } else if (p === "linux") {
    candidates.push(
      "/usr/bin/google-chrome",
      "/usr/bin/google-chrome-stable",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser",
      "/snap/bin/chromium",
    );
  } else if (p === "win32") {
    candidates.push(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
      "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
      `${process.env.LOCALAPPDATA}\\Google\\Chrome\\Application\\chrome.exe`,
    );
  }
  for (const c of candidates) {
    if (c && existsSync(c)) return c;
  }
  return null;
}

const chrome = locateChrome();
if (!chrome) {
  console.error("Could not locate Google Chrome / Chromium. Set CHROME_PATH=... and re-run.");
  process.exit(3);
}

const args = [
  "--headless=new",
  "--disable-gpu",
  "--no-sandbox",
  "--hide-scrollbars",
  "--no-pdf-header-footer",
  "--virtual-time-budget=5000",
  `--print-to-pdf=${outPath}`,
  url,
];

console.log(`Rendering ${url}`);
console.log(`Using:    ${chrome}`);
console.log(`Output:   ${outPath}`);

const proc = spawn(chrome, args, { stdio: ["ignore", "inherit", "inherit"] });
proc.on("exit", (code) => {
  if (code !== 0) {
    console.error(`Chrome exited with code ${code}`);
    process.exit(code ?? 1);
  }
  if (!existsSync(outPath)) {
    console.error("Chrome reported success but the PDF file was not written.");
    process.exit(4);
  }
  const sz = statSync(outPath).size;
  console.log(`OK: wrote ${(sz / 1024).toFixed(1)} KB to ${outPath}`);
});
