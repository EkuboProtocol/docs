import { chromium } from "playwright";
import sharp from "sharp";

const base = process.argv[2] ?? "http://127.0.0.1:4321";
const browser = await chromium.launch();
const failures = [];

for (const scheme of ["light", "dark"]) {
  const context = await browser.newContext({ colorScheme: scheme });
  const page = await context.newPage();
  await page.goto(`${base}/`, { waitUntil: "networkidle" });

  const initial = await page.locator("html").getAttribute("data-theme");
  if (initial !== scheme)
    failures.push(`${scheme}: automatic theme resolved to ${initial}`);

  const button = page.getByRole("button", {
    name: `Switch to ${scheme === "dark" ? "light" : "dark"} theme`,
  });
  if ((await button.count()) < 1) {
    failures.push(`${scheme}: theme toggle is missing its accessible name`);
  } else {
    await button.first().click();
    const expected = scheme === "dark" ? "light" : "dark";
    const toggled = await page.locator("html").getAttribute("data-theme");
    if (toggled !== expected)
      failures.push(`${scheme}: toggle did not switch to ${expected}`);
    await page.reload({ waitUntil: "networkidle" });
    const persisted = await page.locator("html").getAttribute("data-theme");
    if (persisted !== expected)
      failures.push(`${scheme}: explicit theme did not persist`);
  }

  const styles = await page.evaluate(async () => {
    await Promise.all([
      document.fonts.load('16px "Suisse Intl"'),
      document.fonts.load('16px "Suisse Intl Mono"'),
    ]);
    return {
      body: getComputedStyle(document.body).fontFamily,
      bodyLoaded: document.fonts.check('16px "Suisse Intl"'),
      monoLoaded: document.fonts.check('16px "Suisse Intl Mono"'),
      footerLinks: document.querySelectorAll(
        'nav[aria-label="Ekubo properties"] a',
      ).length,
    };
  });
  if (!styles.body.includes("Suisse Intl") || !styles.bodyLoaded)
    failures.push(`${scheme}: Suisse Intl did not load`);
  if (!styles.monoLoaded)
    failures.push(`${scheme}: Suisse Intl Mono did not load`);
  if (styles.footerLinks !== 5)
    failures.push(`${scheme}: property links are not present in the footer`);

  await context.close();
}

// Simulate a cold connection and verify that readable fallback glyphs are
// painted while the preloaded brand face is still downloading.
const coldContext = await browser.newContext({ colorScheme: "light" });
const coldPage = await coldContext.newPage();
await coldPage.route("**/fonts/*.woff2", async (route) => {
  await new Promise((resolve) => setTimeout(resolve, 800));
  await route.continue();
});
await coldPage.goto(`${base}/`, { waitUntil: "domcontentloaded" });
await coldPage.waitForTimeout(100);

const preloadHrefs = await coldPage
  .locator('link[rel="preload"][as="font"]')
  .evaluateAll((links) => links.map((link) => link.getAttribute("href")));
for (const weight of ["400", "600"]) {
  if (!preloadHrefs.some((href) => href?.includes(`-${weight}.`))) {
    failures.push(`cold load: ${weight} font is not preloaded`);
  }
}

if (
  await coldPage.evaluate(() => document.fonts.check('600 32px "Suisse Intl"'))
) {
  failures.push("cold load: delayed Suisse Intl unexpectedly loaded early");
} else {
  const heading = coldPage.locator("h1");
  const box = await heading.boundingBox();
  if (!box) {
    failures.push("cold load: heading has no layout box");
  } else {
    const cdp = await coldContext.newCDPSession(coldPage);
    const capture = await cdp.send("Page.captureScreenshot", {
      format: "png",
      clip: { ...box, scale: 1 },
    });
    const before = Buffer.from(capture.data, "base64");
    await coldPage.evaluate(() => document.fonts.ready);
    const after = await heading.screenshot();
    const paintedPixels = async (image) => {
      const { data, info } = await sharp(image)
        .removeAlpha()
        .raw()
        .toBuffer({ resolveWithObject: true });
      const background = [data[0], data[1], data[2]];
      let painted = 0;
      for (let offset = 0; offset < data.length; offset += info.channels) {
        if (
          data[offset] !== background[0] ||
          data[offset + 1] !== background[1] ||
          data[offset + 2] !== background[2]
        ) {
          painted++;
        }
      }
      return painted;
    };
    if ((await paintedPixels(before)) === 0)
      failures.push("cold load: fallback heading glyphs were not painted");
    if ((await paintedPixels(after)) === 0)
      failures.push("cold load: brand heading glyphs did not render");
  }
}

await coldContext.close();

await browser.close();

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "System-default theme, toggle persistence, visible cold-load fallback, Ekubo fonts, and footer links passed.",
);
