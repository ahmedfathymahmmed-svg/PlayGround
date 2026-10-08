#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p pwd
/usr/bin/time -p bash -c 'test -n "${CAPTURE_URL:?Set CAPTURE_URL}"'
/usr/bin/time -p bash -c 'test -n "${CAPTURE_DIR:?Set CAPTURE_DIR}"'
/usr/bin/time -p mkdir -p "$CAPTURE_DIR"
/usr/bin/time -p node <<'NODE'
const { readFileSync, mkdirSync } = require('fs');
const { join } = require('path');
const { createRequire } = require('module');
const runtime = join(process.env.HOME || '/home/runner', '.local/share/omgithub-playwright');
const requirePlay = createRequire(join(runtime, 'package.json'));
const { chromium } = requirePlay('playwright');
const url = process.env.CAPTURE_URL;
const output = process.env.CAPTURE_DIR;
if (!url || !output) { console.error('Set CAPTURE_URL and CAPTURE_DIR.'); process.exit(1); }
mkdirSync(output, { recursive: true });
let config;
try {
  config = JSON.parse(readFileSync(join(runtime, process.platform === 'darwin' ? 'metal.json' : 'linux.json'), 'utf8'));
} catch (e) { console.error('Failed to read playwright config: ' + e.message); process.exit(1); }
if (process.platform === 'linux') {
  try { process.env.DISPLAY ||= ':' + readFileSync(join(runtime, 'display'), 'utf8').trim(); } catch {}
}
const transient = (error) => { throw Object.assign(error instanceof Error ? error : new Error(String(error)), { exitCode: 75 }); };
(async () => {
  let browser;
  try {
    browser = await chromium.launch({ ...config.browser.launchOptions, timeout: 30000 }).catch(transient);
    for (const [name, width, height] of [['desktop', 1440, 900], ['mobile', 390, 844]]) {
      const page = await browser.newPage({ viewport: { width, height } }).catch(transient);
      try {
        page.setDefaultTimeout(30000);
        page.on('pageerror', (e) => console.error(e.message));
        const response = await page.goto(url, { waitUntil: 'load', timeout: 45000 }).catch(transient);
        if (!response || !response.ok()) {
          const status = response ? response.status() : 0;
          const isTransient = !response || [408, 429, 500, 502, 503, 504].includes(status);
          throw Object.assign(new Error(`HTTP ${status || 'no-response'} loading preview`), { exitCode: isTransient ? 75 : 1 });
        }
        await page.locator(process.env.CAPTURE_READY_SELECTOR || 'body').waitFor({ state: 'visible', timeout: 30000 }).catch((e) => {
          if (e.name === 'TimeoutError') transient(e);
          throw Object.assign(e, { exitCode: 1 });
        });
        await page.waitForFunction(() => document.fonts.status === 'loaded', { timeout: 30000 }).catch(() => {});
        await page.waitForTimeout(1000);
        const html = await page.content().catch(() => '');
        if (!html || html.length < 200 || !html.includes('PlayGround')) {
          throw Object.assign(new Error('Rendered content check failed: expected marker missing.'), { exitCode: 1 });
        }
        await page.screenshot({ path: join(output, `final-${name}.png`), timeout: 30000 }).catch((error) => {
          if (error.name === 'TimeoutError' || !browser.isConnected()) transient(error);
          throw error;
        });
        console.log(`Capture ${name}: ok`);
      } finally {
        await page.close().catch(() => {});
      }
    }
  } catch (error) {
    console.error(error);
    process.exitCode = error.exitCode || 1;
  } finally {
    await browser?.close().catch((error) => { console.error(error); process.exitCode ||= 75; });
  }
})();
NODE
/usr/bin/time -p ls -l "$CAPTURE_DIR"
