import { readFile } from "node:fs/promises";
import { chromium } from "playwright";

const base = process.argv[2] ?? "http://127.0.0.1:4321";
const browser = await chromium.launch();
const page = await browser.newPage();
const failures = [];

page.on("pageerror", (error) => failures.push(`page error: ${error.message}`));

const response = await page.goto(`${base}/wallet/policies/`, {
  waitUntil: "networkidle",
});
if (!response || response.status() >= 400) {
  failures.push(`policy page: HTTP ${response?.status() ?? "none"}`);
} else {
  const editor = page.locator('#policy-json-editor[data-ready="true"]');
  await editor.waitFor();

  const status = page.locator("#policy-editor-status");
  if (!(await status.textContent())?.startsWith("Valid JSON")) {
    failures.push(`starter policy is not valid: ${await status.textContent()}`);
  }

  const schemaResponse = await page.request.get(
    `${base}/schemas/ekubo-wallet-policy.schema.json`,
  );
  const expectedSchema = await readFile(
    new URL("../src/data/ekubo-wallet-policy.schema.json", import.meta.url),
    "utf8",
  );
  if (!schemaResponse.ok()) {
    failures.push(`policy schema: HTTP ${schemaResponse.status()}`);
  } else {
    if (
      !["application/json", "application/schema+json"].includes(
        schemaResponse.headers()["content-type"],
      )
    ) {
      failures.push(
        `policy schema: unexpected content type ${schemaResponse.headers()["content-type"]}`,
      );
    }
    if ((await schemaResponse.text()) !== expectedSchema) {
      failures.push(
        "published policy schema differs from the vendored artifact",
      );
    }
  }

  const firstLine = page.locator("#policy-json-editor .cm-line").first();
  await firstLine.click({ position: { x: 8, y: 8 } });
  await page.keyboard.press("End");
  await page.keyboard.press("Enter");
  await page.keyboard.type('"unexpected": true,');
  await page.waitForFunction(
    () =>
      document.querySelector("#policy-editor-status")?.dataset.state ===
      "invalid",
  );
  if ((await page.locator(".cm-lintRange-error").count()) === 0) {
    failures.push(
      "schema-invalid property did not receive an inline diagnostic",
    );
  }

  await page.locator("#reset-policy").click();
  await page.waitForFunction(() =>
    document
      .querySelector("#policy-editor-status")
      ?.textContent?.startsWith("Valid JSON"),
  );

  await firstLine.click({ position: { x: 8, y: 8 } });
  await page.keyboard.press("End");
  await page.keyboard.press("Enter");
  await page.keyboard.type('"');
  await page.keyboard.press("Control+Space");
  const completion = page.locator(".cm-tooltip-autocomplete");
  await completion.waitFor();
  if (!(await completion.textContent())?.includes("$schema")) {
    failures.push("schema-driven property completion did not offer $schema");
  }
}

await browser.close();

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Policy editor loaded a valid starter document, published the canonical schema, reported schema errors inline, and offered schema-driven completion.",
);
