/**
 * Runs axe's WCAG 2.1 AA and best-practice rules over every sitemap page in
 * both themes. This deliberately mirrors the blog's accessibility gate.
 *
 *   bun run check:a11y
 *   bun run check:a11y -- https://docs.example.com
 */
import { readFileSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { chromium } from "playwright";

const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "best-practice"];
const PATHS = [
  ...readFileSync(
    new URL("../dist/sitemap-0.xml", import.meta.url),
    "utf8",
  ).matchAll(/<loc>([^<]+)<\/loc>/g),
].map((match) => new URL(match[1]).pathname);

const base = process.argv[2] ?? "http://127.0.0.1:4321";
const browser = await chromium.launch();
const failures = [];
let incomplete = 0;

for (const scheme of ["light", "dark"]) {
  const context = await browser.newContext({ colorScheme: scheme });
  const page = await context.newPage();

  for (const path of PATHS) {
    const response = await page.goto(`${base}${path}`, {
      waitUntil: "networkidle",
    });
    if (!response || response.status() >= 400) {
      failures.push(`${scheme} ${path}: HTTP ${response?.status() ?? "none"}`);
      continue;
    }

    // Audit both the lightweight API landing state and the full explorer.
    if (path === "/api/") {
      const landingResults = await new AxeBuilder({ page })
        .withTags(TAGS)
        .analyze();
      incomplete += landingResults.incomplete.length;
      for (const violation of landingResults.violations) {
        const target = violation.nodes[0]?.target.join(" > ") ?? "unknown";
        failures.push(
          `${scheme} ${path} landing: ${violation.id} (${violation.impact}) at ${target}`,
        );
      }
      await page
        .getByRole("button", { name: "Load interactive reference" })
        .click();
      await page
        .locator("#scalar-reference > *")
        .first()
        .waitFor({ timeout: 20_000 });
      // Scalar renders in several mutation batches. Let the final batch and
      // the page's accessibility repair observer settle before auditing it.
      await page.waitForTimeout(1_000);
    }

    const results = await new AxeBuilder({ page }).withTags(TAGS).analyze();
    incomplete += results.incomplete.length;
    for (const violation of results.violations) {
      const target = violation.nodes[0]?.target.join(" > ") ?? "unknown";
      failures.push(
        `${scheme} ${path}: ${violation.id} (${violation.impact}) at ${target}`,
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
  `No accessibility violations across ${PATHS.length * 2} page/theme combinations` +
    (incomplete ? ` (${incomplete} needs-review items)` : "") +
    ".",
);
