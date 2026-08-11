import { access, readFile, readdir } from "node:fs/promises";
import { join } from "node:path";

async function walk(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await walk(path)));
    else files.push(path);
  }
  return files;
}

const htmlFiles = (await walk("dist")).filter((file) => file.endsWith(".html"));
const failures = [];

for (const sourceFile of htmlFiles) {
  const html = await readFile(sourceFile, "utf8");
  const sourcePath = `/${sourceFile.replace(/^dist\//, "").replace(/index\.html$/, "")}`;
  for (const match of html.matchAll(/\b(?:href|src)="([^"]+)"/g)) {
    const value = match[1];
    if (/^(?:https?:|mailto:|tel:|data:|javascript:)/.test(value)) continue;

    const url = new URL(value, `https://docs.ekubo.org${sourcePath}`);
    let target = decodeURIComponent(url.pathname);
    if (target.endsWith("/")) target += "index.html";
    else if (!target.split("/").at(-1)?.includes(".")) target += "/index.html";
    const targetFile = join("dist", target.replace(/^\//, ""));

    try {
      await access(targetFile);
    } catch {
      failures.push(`${sourcePath} -> ${value} (missing ${targetFile})`);
      continue;
    }

    if (url.hash && targetFile.endsWith(".html")) {
      const targetHtml =
        targetFile === sourceFile ? html : await readFile(targetFile, "utf8");
      const id = decodeURIComponent(url.hash.slice(1));
      if (!targetHtml.includes(`id="${id}"`))
        failures.push(`${sourcePath} -> ${value} (missing fragment)`);
    }
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  console.error(`\n${failures.length} broken internal links`);
  process.exit(1);
}

console.log(`Checked internal links in ${htmlFiles.length} HTML files.`);
