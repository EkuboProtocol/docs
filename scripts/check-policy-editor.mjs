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

  const editorGeometry = await editor.evaluate((host) => {
    const codeMirror = host.querySelector(".cm-editor");
    const scroller = host.querySelector(".cm-scroller");
    const gutters = host.querySelector(".cm-gutters");
    const codeLines = host.querySelectorAll(".cm-line");
    const lineNumbers = host.querySelectorAll(
      ".cm-lineNumbers .cm-gutterElement",
    );
    const firstCodeLine = codeLines.item(0).getBoundingClientRect();
    const lastCodeLine = codeLines
      .item(codeLines.length - 1)
      .getBoundingClientRect();
    const firstLineNumber = lineNumbers.item(1).getBoundingClientRect();
    const lastLineNumber = lineNumbers
      .item(lineNumbers.length - 1)
      .getBoundingClientRect();
    return {
      editorHeight: codeMirror?.getBoundingClientRect().height ?? 0,
      scrollerHeight: scroller?.getBoundingClientRect().height ?? 0,
      gutterHeight: gutters?.getBoundingClientRect().height ?? 0,
      lineCount: codeLines.length,
      lastLineNumberText: lineNumbers.item(lineNumbers.length - 1).textContent,
      firstLineOffset: Math.abs(firstCodeLine.top - firstLineNumber.top),
      lastLineOffset: Math.abs(lastCodeLine.bottom - lastLineNumber.bottom),
    };
  });
  if (
    editorGeometry.lineCount < 14 ||
    Number(editorGeometry.lastLineNumberText) < 14 ||
    editorGeometry.scrollerHeight + 1 < editorGeometry.editorHeight ||
    editorGeometry.gutterHeight + 1 < editorGeometry.editorHeight ||
    editorGeometry.firstLineOffset > 1 ||
    editorGeometry.lastLineOffset > 1
  ) {
    failures.push(
      "editor does not fill its minimum height with numbered document lines",
    );
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
      !["application/json", "application/schema+json"].some((type) =>
        schemaResponse.headers()["content-type"]?.startsWith(type),
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

  const buttonGeometry = await page
    .locator(".policy-editor-actions button")
    .evaluateAll((buttons) =>
      buttons.map((button) => {
        const box = button.getBoundingClientRect();
        return {
          top: box.top,
          height: box.height,
          marginTop: getComputedStyle(button).marginTop,
        };
      }),
    );
  if (
    buttonGeometry.length !== 2 ||
    buttonGeometry.some(({ marginTop }) => marginTop !== "0px") ||
    Math.abs(buttonGeometry[0].top - buttonGeometry[1].top) > 1 ||
    Math.abs(buttonGeometry[0].height - buttonGeometry[1].height) > 1
  ) {
    failures.push("Format and Reset controls are not aligned consistently");
  }

  const versionLine = page
    .locator("#policy-json-editor .cm-line")
    .filter({ hasText: '"version"' })
    .first();
  await versionLine.click({ position: { x: 90, y: 8 } });
  const lineBox = await versionLine.boundingBox();
  const cursorBox = await page.locator(".cm-cursor-primary").boundingBox();
  if (
    !lineBox ||
    !cursorBox ||
    cursorBox.y + cursorBox.height < lineBox.y ||
    cursorBox.y > lineBox.y + lineBox.height
  ) {
    failures.push("editor caret is not positioned on the clicked line");
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

  const content = page.locator("#policy-json-editor .cm-content");
  const selectAll = process.platform === "darwin" ? "Meta+A" : "Control+A";
  const compactPolicy = '{"version":1,"rules":[]}';
  await content.click();
  await page.keyboard.press(selectAll);
  await page.keyboard.insertText(compactPolicy);
  if ((await page.locator("#policy-json-editor .cm-line").count()) < 14) {
    failures.push("editing allowed the document below its minimum line count");
  }
  await page.locator("#format-policy").click();
  await page.waitForFunction(() =>
    document
      .querySelector("#policy-editor-status")
      ?.textContent?.startsWith("Valid JSON"),
  );
  if ((await page.locator("#policy-json-editor .cm-line").count()) < 4) {
    failures.push("Format did not expand compact JSON");
  }

  await content.click();
  await page.keyboard.press(selectAll);
  await page.keyboard.insertText('{"version":1,"rules":[{"effect":""}]}');
  for (let index = 0; index < 4; index += 1) {
    await page.keyboard.press("ArrowLeft");
  }
  await page.keyboard.press("Control+Space");
  const completion = page.locator(".cm-tooltip-autocomplete");
  await completion.waitFor();
  const completionText = await completion.textContent();
  if (!completionText?.includes("allow") || !completionText.includes("deny")) {
    failures.push("effect completion did not offer allow and deny");
  }

  await page.locator("#reset-policy").click();
  await page.waitForFunction(() =>
    document
      .querySelector("#policy-editor-status")
      ?.textContent?.startsWith("Valid JSON"),
  );
}

await browser.close();

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Policy editor published the canonical schema; filled its minimum height with numbered lines; kept controls and caret aligned; formatted and reset JSON; reported inline errors; and completed effect with allow and deny.",
);
