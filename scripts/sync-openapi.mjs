import { mkdir, writeFile } from "node:fs/promises";

const specs = [
  {
    name: "ekubo",
    url: "https://prod-api.ekubo.org/openapi.json",
    expectedTitle: "Ekubo API",
  },
  {
    name: "quoter",
    url: "https://prod-api-quoter.ekubo.org/openapi.json",
    expectedTitle: "Ekubo Quoter API",
  },
];

const methods = new Set([
  "get",
  "put",
  "post",
  "delete",
  "patch",
  "options",
  "head",
  "trace",
]);

await Promise.all([
  mkdir("schemas", { recursive: true }),
  mkdir("public/openapi", { recursive: true }),
]);

for (const { name, url, expectedTitle } of specs) {
  const response = await fetch(url, {
    headers: { accept: "application/json" },
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok)
    throw new Error(
      `Could not download ${name} OpenAPI document: HTTP ${response.status}`,
    );

  const document = await response.json();
  if (document.openapi !== "3.1.0")
    throw new Error(`${name} must use OpenAPI 3.1.0; got ${document.openapi}`);
  if (document.info?.title !== expectedTitle)
    throw new Error(
      `${name} title changed unexpectedly to ${document.info?.title}`,
    );
  if (!document.paths || typeof document.paths !== "object")
    throw new Error(`${name} has no paths object`);

  const operationIds = [];
  for (const pathItem of Object.values(document.paths)) {
    for (const [method, operation] of Object.entries(pathItem ?? {})) {
      if (!methods.has(method)) continue;
      if (!operation?.operationId)
        throw new Error(`${name} contains an operation without operationId`);
      operationIds.push(operation.operationId);
    }
  }
  if (new Set(operationIds).size !== operationIds.length)
    throw new Error(`${name} contains duplicate operationIds`);

  const serialized = `${JSON.stringify(document, null, 2)}\n`;
  await Promise.all([
    writeFile(`schemas/${name}.json`, serialized),
    writeFile(`public/openapi/${name}.json`, serialized),
  ]);
  console.log(`Synced ${name}: ${operationIds.length} operations`);
}
