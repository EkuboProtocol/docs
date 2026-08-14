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
  await page.evaluate(() => document.fonts.ready);

  const status = page.locator("#policy-editor-status");
  if (!(await status.textContent())?.startsWith("Valid JSON")) {
    failures.push(`starter policy is not valid: ${await status.textContent()}`);
  }
  const content = page.locator("#policy-json-editor .cm-content");
  const exampleSelect = page.locator("#policy-example");
  const restoreDefault = async () => {
    if ((await exampleSelect.inputValue()) === "review") {
      await exampleSelect.selectOption("deny-all");
    }
    await exampleSelect.selectOption("review");
    await page.waitForFunction(() =>
      document
        .querySelector("#policy-editor-status")
        ?.textContent?.startsWith("Valid JSON"),
    );
  };

  if (
    (await page.locator("#policy-example option").first().textContent()) !==
    "Review every transaction (Default)"
  ) {
    failures.push("review example is not labeled as the default");
  }
  if (
    (await page
      .locator("#reset-policy, #format-policy, #load-policy-example")
      .count()) !== 0
  ) {
    failures.push("obsolete editor action buttons are still rendered");
  }
  const selectStyle = await exampleSelect.evaluate((select) => {
    const style = getComputedStyle(select);
    const arrow = getComputedStyle(select.parentElement, "::after");
    return {
      appearance: style.appearance,
      paddingRight: Number.parseFloat(style.paddingRight),
      arrowRight: Number.parseFloat(arrow.right),
    };
  });
  if (
    selectStyle.appearance !== "none" ||
    selectStyle.paddingRight < 32 ||
    selectStyle.arrowRight < 8
  ) {
    failures.push("example select arrow does not have enough right padding");
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

  const examples = [
    ["review", 0],
    ["deny-all", 1],
    ["deny-native-value", 1],
    ["constrained-call", 1],
    ["single-purpose", 2],
  ];
  for (const [value, expectedRuleCount] of examples) {
    await exampleSelect.selectOption(value);
    if (
      !(await page.locator("#policy-example-description").textContent())?.trim()
    ) {
      failures.push(`${value} example has no description`);
    }
    await page.waitForFunction(() =>
      document
        .querySelector("#policy-editor-status")
        ?.textContent?.startsWith("Valid JSON"),
    );
    const text = await content.innerText();
    try {
      const example = JSON.parse(text);
      if (example.rules?.length !== expectedRuleCount || !text.includes("\n")) {
        failures.push(`${value} example did not load as formatted JSON`);
      }
    } catch {
      failures.push(`${value} example did not load valid JSON`);
    }
  }
  const singlePurposeExample = JSON.parse(await content.innerText());
  if (
    singlePurposeExample.rules?.[0]?.calldata?.selector?.abi !==
    "approve(address spender, uint256 amount)"
  ) {
    failures.push("single-purpose example did not load its calldata predicate");
  }
  const finalRule = singlePurposeExample.rules?.at(-1);
  if (
    finalRule?.effect !== "deny" ||
    Object.keys(finalRule).some((key) =>
      ["chain_id", "to", "native_value", "calldata"].includes(key),
    )
  ) {
    failures.push("single-purpose example does not end with deny all");
  }
  await restoreDefault();
  await page.evaluate(
    () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve)),
      ),
  );

  const versionLine = page
    .locator("#policy-json-editor .cm-line")
    .filter({ hasText: '"version"' })
    .first();
  await versionLine.click({ position: { x: 90, y: 8 } });
  const lineBox = await versionLine.boundingBox();
  const cursorBox = await page.locator(".cm-cursor-primary").boundingBox();
  const focusedEditorStyle = await page
    .locator("#policy-json-editor .cm-editor.cm-focused")
    .evaluate((element) => {
      const style = getComputedStyle(element);
      return style.outlineStyle;
    });
  if (focusedEditorStyle !== "none") {
    failures.push("focused editor still renders an outer outline");
  }
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
  await exampleSelect.focus();
  if (!(await content.innerText()).includes('"unexpected"')) {
    failures.push("automatic formatting changed invalid JSON");
  }

  await restoreDefault();

  const selectAll = process.platform === "darwin" ? "Meta+A" : "Control+A";
  const compactPolicy = '{"version":1,"rules":[]}';
  await content.click();
  await page.keyboard.press(selectAll);
  await page.keyboard.insertText(compactPolicy);
  if ((await page.locator("#policy-json-editor .cm-line").count()) < 14) {
    failures.push("editing allowed the document below its minimum line count");
  }
  await exampleSelect.focus();
  await page.waitForFunction(() =>
    document
      .querySelector("#policy-editor-status")
      ?.textContent?.startsWith("Valid JSON"),
  );
  const formattedText = await content.innerText();
  if (formattedText.split("\n").filter((line) => line.trim()).length < 4) {
    failures.push("valid compact JSON was not formatted automatically");
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

  await restoreDefault();
}

await browser.close();

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Policy editor published the canonical schema; loaded five examples immediately on selection; marked and restored the default; inset the select arrow; automatically formatted valid JSON; preserved invalid edits; filled its minimum height with numbered lines; kept focus visible through the caret and active line without an outer outline; reported inline errors; and completed effect with allow and deny.",
);
