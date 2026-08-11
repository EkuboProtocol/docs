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
      await page.locator("#app > *").first().waitFor({ timeout: 20_000 });
    } catch {
      failures.push(`${scheme}: Scalar did not render`);
    }

    const pageText = await page.locator("body").innerText();
    if (!pageText.includes("Test Request"))
      failures.push(`${scheme}: request testing is not available`);

    const sourceButton = page.getByRole("button", {
      name: "Ekubo API",
      exact: true,
    });
    try {
      await sourceButton.evaluate((button) => {
        if (button instanceof HTMLElement) button.click();
      });
      const quoterOption = page.getByText("Quoter API", { exact: true });
      await quoterOption.waitFor({ timeout: 5_000 });
      await quoterOption.evaluate((option) => {
        if (option instanceof HTMLElement) option.click();
      });
      await page
        .getByRole("button", { name: "Quoter API", exact: true })
        .waitFor({ timeout: 5_000 });
    } catch {
      failures.push(`${scheme}: both OpenAPI sources are not discoverable`);
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

    const expectedClass = `${scheme}-mode`;
    if (
      !(await page.locator("body").getAttribute("class"))?.includes(
        expectedClass,
      )
    )
      failures.push(`${scheme}: API reference did not follow the system theme`);
  }

  await context.close();
}

await browser.close();

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Unified API reference rendered both specs with the Ekubo fonts in light and dark themes.",
);
