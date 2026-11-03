#!/usr/bin/env node
// preview_shots.cjs — screenshots of a dataset's private preview, for the preview's landing page
// (Ben + Erin, 2026-11-03: a picture of their data on the site, in the Explorer and the Finder pulls
// a provider into clicking through). Runs after the build is on show, against the live link, with
// the Chrome on this machine through puppeteer-core (from the Explorer checkout's node_modules:
// NODE_PATH=$EXPLORE_DIR/node_modules).
//
//   node scripts/preview_shots.cjs <out_dir> <page_url> [<page_url> …]
//
// Each URL becomes <out_dir>/<n>.png (1280 × 800, device scale 1, ?tour=off added when absent,
// light theme). A page that fails to load is reported and skipped: the landing page shows a
// placeholder for it, never a broken image.
const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer-core");

const CHROME = process.env.CHROME_PATH || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const [out, ...urls] = process.argv.slice(2);
if (!out || !urls.length) { console.error("usage: preview_shots.cjs <out_dir> <url> …"); process.exit(2); }
fs.mkdirSync(out, { recursive: true });

(async () => {
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: "new",
    args: ["--no-sandbox", "--disable-gpu", "--hide-scrollbars", "--window-size=1280,800"] });
  let failed = 0;
  for (let i = 0; i < urls.length; i++) {
    const u = new URL(urls[i]);
    if (!u.searchParams.has("tour")) u.searchParams.set("tour", "off");
    if (!u.searchParams.has("theme")) u.searchParams.set("theme", "light");
    const file = path.join(out, `${i + 1}.png`);
    const page = await browser.newPage();
    try {
      await page.setViewport({ width: 1280, height: 800, deviceScaleFactor: 1 });
      await page.goto(u.href, { waitUntil: "networkidle2", timeout: 90000 });
      await new Promise((r) => setTimeout(r, 2500));          // maps and charts finish drawing
      await page.screenshot({ path: file, type: "png" });
      console.log(`${file}  ${u.href}`);
    } catch (e) {
      failed++; console.error(`skipped ${u.href}: ${e.message}`);
    } finally { await page.close(); }
  }
  await browser.close();
  process.exit(failed === urls.length ? 1 : 0);
})();
