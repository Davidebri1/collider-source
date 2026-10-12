// Phone-portrait capture: 430x932 logical at 3x, the only view that matters.
// Usage: node tools/shoot.mjs <name> <deepLinkQuery> [waitMs]
import puppeteer from 'puppeteer-core';

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const BASE = 'http://127.0.0.1:28700/';
const OUT = 'C:/Users/D/Documents/Collider/audit-shots';

const shots = process.argv.slice(2);
if (!shots.length) { console.error('need at least one <name>=<query> pair'); process.exit(1); }

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--autoplay-policy=no-user-gesture-required'],
});

for (const spec of shots) {
  const eq = spec.indexOf('=');
  const name = spec.slice(0, eq);
  const query = spec.slice(eq + 1);
  const waitMs = Number(spec.split('|')[2] || 9000);
  const page = await browser.newPage();
  await page.setViewport({ width: 430, height: 932, deviceScaleFactor: 3, isMobile: true, hasTouch: true });
  await page.goto(BASE + (query ? '?' + query : ''), { waitUntil: 'networkidle2', timeout: 90000 }).catch(() => {});
  await new Promise(r => setTimeout(r, waitMs));
  await page.screenshot({ path: `${OUT}/${name}.png` });
  console.log(`${name} <- ${query}`);
  await page.close();
}

await browser.close();
console.log('done');