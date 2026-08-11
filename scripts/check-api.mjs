import { chromium } from "playwright";

const base = process.argv[2] ?? "http://127.0.0.1:4321";
const browser = await chromium.launch();
const failures = [];

for (const scheme of ["light", "dark"]) {
  const context = await browser.newContext({ colorScheme: scheme });
  const page = await context.newPage();
  const response = await page.goto(`${base}/api/`, {
    waitUntil: "networkidle",
  });

  if (!response || response.status() >= 400) {
    failures.push(`${scheme}: HTTP ${response?.status() ?? "none"}`);
  } else {
    try {
      await page
        .locator("#scalar-reference > *")
        .first()
        .waitFor({ timeout: 20_000 });
    } catch {
      failures.push(`${scheme}: Scalar did not render`);
    }

    try {
      await page.getByRole("button", { name: /List tokens/ }).click({
        timeout: 5_000,
      });
      await page
        .getByRole("button", { name: /Test Request/ })
        .first()
        .click({
          timeout: 5_000,
        });
      await page
        .getByRole("dialog", { name: "API Client" })
        .waitFor({ timeout: 5_000 });
      await page.getByRole("button", { name: "Close Client" }).click({
        timeout: 5_000,
      });
      await page
        .getByRole("dialog", { name: "API Client" })
        .waitFor({ state: "hidden", timeout: 5_000 });
    } catch {
      failures.push(`${scheme}: endpoint testing panel is not interactive`);
    }

    await page.evaluate(() => window.scrollTo(0, 1_800));
    await page.waitForTimeout(100);

    const sharedHeader = page.locator("body > .page > .header");
    const endpointSearch = page.getByRole("button", { name: /Open Search/ });
    const [headerBox, endpointSearchBox] = await Promise.all([
      sharedHeader.boundingBox(),
      endpointSearch.boundingBox(),
    ]);
    if (
      !headerBox ||
      !endpointSearchBox ||
      endpointSearchBox.y < headerBox.y + headerBox.height
    ) {
      failures.push(`${scheme}: endpoint search overlaps the shared header`);
    }

    try {
      await endpointSearch.click({ timeout: 5_000 });
      const endpointSearchDialog = page.getByRole("dialog", { name: "Search" });
      await endpointSearchDialog
        .getByRole("combobox", { name: "Enter search query" })
        .fill("revenue");
      await endpointSearchDialog
        .getByRole("option", { name: /Get revenue/ })
        .first()
        .waitFor({ timeout: 5_000 });
      await page.keyboard.press("Escape");
      await endpointSearchDialog.waitFor({ state: "hidden", timeout: 5_000 });
    } catch {
      failures.push(`${scheme}: endpoint search is not usable`);
    }

    try {
      const docsSearch = sharedHeader.getByRole("button", { name: /Search/ });
      await docsSearch.click({ timeout: 5_000 });
      const docsSearchDialog = page.getByRole("dialog", { name: "Search" });
      await docsSearchDialog
        .getByRole("textbox", { name: "Search" })
        .fill("governance");
      await docsSearchDialog
        .getByRole("link", { name: "Participate in governance", exact: true })
        .first()
        .waitFor({ timeout: 5_000 });
      await page.keyboard.press("Escape");
      await docsSearchDialog.waitFor({ state: "hidden", timeout: 5_000 });
    } catch {
      failures.push(`${scheme}: docs search is not usable`);
    }

    const sourceButton = page.getByRole("button", {
      name: "Ekubo API",
      exact: true,
    });
    try {
      // Use real pointer actions so an overlay cannot silently intercept the UI.
      await sourceButton.click({ timeout: 5_000 });
      const quoterOption = page.getByRole("option", {
        name: "Quoter API",
        exact: true,
      });
      await quoterOption.waitFor({ timeout: 5_000 });
      await quoterOption.click({ timeout: 5_000 });
      await page
        .getByRole("button", { name: "Quoter API", exact: true })
        .waitFor({ timeout: 5_000 });
    } catch {
      failures.push(`${scheme}: source selector is not pointer-interactive`);
    }

    const reference = page.locator("#scalar-reference");
    await reference.hover();
    const beforeScroll = await page.evaluate(() => window.scrollY);
    await page.mouse.wheel(0, 700);
    await page.waitForTimeout(100);
    const afterScroll = await page.evaluate(() => window.scrollY);
    if (afterScroll <= beforeScroll) {
      failures.push(
        `${scheme}: API reference does not respond to wheel scrolling`,
      );
    }

    const styles = await page.evaluate(() => ({
      body: getComputedStyle(document.body).fontFamily,
      code: getComputedStyle(document.querySelector("code") ?? document.body)
        .fontFamily,
    }));
    if (!styles.body.includes("Suisse Intl"))
      failures.push(`${scheme}: body is not using Suisse Intl`);
    if (!styles.code.includes("Suisse Intl Mono"))
      failures.push(`${scheme}: code is not using Suisse Intl Mono`);

    if ((await page.locator("html").getAttribute("data-theme")) !== scheme)
      failures.push(`${scheme}: API reference did not follow the system theme`);

    if ((await page.locator(".scalar-api-reference").count()) !== 1)
      failures.push(`${scheme}: expected exactly one embedded API explorer`);

    try {
      await page
        .getByRole("link", { name: /Ekubo Docs/ })
        .first()
        .waitFor({ timeout: 2_000 });
      await page
        .getByRole("navigation", { name: "Ekubo properties" })
        .waitFor({ timeout: 2_000 });
    } catch {
      failures.push(
        `${scheme}: API reference is missing the shared docs shell`,
      );
    }
  }

  await context.close();
}

await browser.close();

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Embedded API reference rendered in the docs shell, kept both searches usable while scrolled, opened its test panel, and switched specs with real pointer input in both themes.",
);
