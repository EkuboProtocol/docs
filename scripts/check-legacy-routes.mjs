import { existsSync, readFileSync } from "node:fs";
import { buildRedirects, fileToRoute, legacyFiles } from "./legacy-routes.mjs";

const failures = [];
const redirects = new Map(
  readFileSync(new URL("../dist/_redirects", import.meta.url), "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [source, target] = line.split(/\s+/);
      return [source, target];
    }),
);

for (const file of legacyFiles) {
  const route = fileToRoute(file);
  const output =
    route === "/"
      ? new URL("../dist/index.html", import.meta.url)
      : new URL(`../dist${route}index.html`, import.meta.url);
  if (!existsSync(output))
    failures.push(`${file}: missing built route ${route}`);
}

for (const [source, target] of buildRedirects()) {
  if (redirects.get(source) !== target) {
    failures.push(`${source}: expected redirect to ${target}`);
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  `All ${legacyFiles.length} GitBook pages and ${redirects.size} legacy URL variants resolve.`,
);
