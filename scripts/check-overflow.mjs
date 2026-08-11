/**
 * Checks every sitemap page at the same six phone widths used by the blog.
 *
 *   bun run check:overflow
 *   bun run check:overflow -- https://docs.example.com
 */
import { readFileSync } from "node:fs";
import { chromium } from "playwright";

const WIDTHS = [320, 360, 375, 390, 412, 430];
const PATHS = [
  ...readFileSync(
    new URL("../dist/sitemap-0.xml", import.meta.url),
    "utf8",
  ).matchAll(/<loc>([^<]+)<\/loc>/g),
].map((match) => new URL(match[1]).pathname);

const base = process.argv[2] ?? "http://127.0.0.1:4321";
const browser = await chromium.launch();
const failures = [];

for (const width of WIDTHS) {
  const context = await browser.newContext({
    viewport: { width, height: 800 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();

  for (const path of PATHS) {
    const response = await page.goto(`${base}${path}`, {
      waitUntil: "networkidle",
    });
    if (!response || response.status() >= 400) {
      failures.push(`${width}px ${path}: HTTP ${response?.status() ?? "none"}`);
      continue;
    }

    const result = await page.evaluate((viewportWidth) => {
      const offenders = new Set();
      document.querySelectorAll("body *").forEach((element) => {
        if (element.getBoundingClientRect().right > viewportWidth + 0.5) {
          offenders.add(
            element.tagName +
              (element.className
                ? `.${String(element.className).split(" ")[0]}`
                : ""),
          );
        }
      });
      return {
        overflow: document.documentElement.scrollWidth - viewportWidth,
        offenders: [...offenders].slice(0, 5),
      };
    }, width);

    if (result.overflow > 0) {
      failures.push(
        `${width}px ${path}: +${result.overflow}px (${result.offenders.join(", ")})`,
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
  `No horizontal overflow across ${WIDTHS.length * PATHS.length} page/width combinations.`,
);
