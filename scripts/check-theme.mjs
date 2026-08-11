import { chromium } from "playwright";

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

await browser.close();

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "System-default theme, toggle persistence, Ekubo fonts, and footer links passed in both color schemes.",
);
