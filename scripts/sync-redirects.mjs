import { writeFileSync } from "node:fs";
import { buildRedirects } from "./legacy-routes.mjs";

const redirects = buildRedirects();
const output =
  [...redirects]
    .map(([source, target]) => `${source} ${target} 301`)
    .join("\n") + "\n";

writeFileSync(new URL("../public/_redirects", import.meta.url), output);
console.log(`Synced ${redirects.size} legacy redirects.`);
