import { readFileSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { chromium } from "playwright";

const sitemapPaths = [
  ...readFileSync(
    new URL("../dist/sitemap-0.xml", import.meta.url),
    "utf8",
  ).matchAll(/<loc>([^<]+)<\/loc>/g),
].map((match) => new URL(match[1]).pathname);

const paths = sitemapPaths.filter(
  (path) =>
    !path.startsWith("/api-explorer/") &&
    (!path.startsWith("/api/") ||
      path === "/api/ekubo/" ||
      path.includes("/get_listtokens/")),
);
const base = process.argv[2] ?? "http://127.0.0.1:4321";
const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 360, height: 800 },
  colorScheme: "light",
});
const page = await context.newPage();
const failures = [];

for (const path of paths) {
  const response = await page.goto(`${base}${path}`, {
    waitUntil: "domcontentloaded",
  });
  if (!response || response.status() >= 400) {
    failures.push(`${path}: HTTP ${response?.status() ?? "no response"}`);
    continue;
  }
  if (!(await page.locator("h1").first().isVisible()))
    failures.push(`${path}: no visible H1`);
  const overflow = await page.evaluate(
    () =>
      document.documentElement.scrollWidth -
      document.documentElement.clientWidth,
  );
  if (overflow > 1)
    failures.push(`${path}: ${overflow}px horizontal overflow at 360px`);

  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();
  for (const violation of results.violations) {
    const target = violation.nodes[0]?.target.join(" > ") ?? "unknown target";
    failures.push(
      `${path}: axe ${violation.id} (${violation.impact}) at ${target}`,
    );
  }
}

for (const explorer of ["/api-explorer/ekubo/", "/api-explorer/quoter/"]) {
  const response = await page.goto(`${base}${explorer}`, {
    waitUntil: "domcontentloaded",
  });
  if (!response || response.status() >= 400)
    failures.push(`${explorer}: HTTP ${response?.status() ?? "no response"}`);
  try {
    await page
      .locator("#app > *")
      .first()
      .waitFor({ state: "visible", timeout: 20_000 });
  } catch {
    failures.push(`${explorer}: Scalar did not render`);
  }
}

await browser.close();

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(
  `Browser, mobile overflow, and accessibility checks passed for ${paths.length} static pages and both Scalar explorers.`,
);
