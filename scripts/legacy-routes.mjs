export const legacyFiles = [
  "README.md",
  "about-ekubo/features.md",
  "about-ekubo/v3-whitepaper.md",
  "about-ekubo/vision.md",
  "concepts/architecture.md",
  "concepts/extensions-vs-v4-hooks.md",
  "concepts/extensions.md",
  "concepts/key-concepts.md",
  "integration-guides/README.md",
  "integration-guides/aggregators.md",
  "integration-guides/reading-pool-price.md",
  "integration-guides/sdks.md",
  "integration-guides/signed-exclusive-swaps.md",
  "integration-guides/swapping.md",
  "integration-guides/yul-router.md",
  "products/README.md",
  "products/governance.md",
  "products/indexer.md",
  "products/liquidity.md",
  "products/mcp-server.md",
  "products/rewards.md",
  "products/trading.md",
  "products/ve33.md",
  "reference/audits.md",
  "reference/contracts/README.md",
  "reference/contracts/evm-v2.md",
  "reference/contracts/evm-v3.md",
  "reference/contracts/governance.md",
  "reference/contracts/starknet.md",
  "reference/ekubo-api/README.md",
  "reference/ekubo-api/endpoints.md",
  "reference/pool-math.md",
  "reference/price-representation.md",
  "reference/quoter-api.md",
  "user-guides/add-liquidity.md",
  "user-guides/dollar-cost-average-orders.md",
  "user-guides/ekubo-token.md",
  "user-guides/governance.md",
];

export const movedRoutes = {
  "concepts/extensions/extensions-vs-v4-hooks":
    "concepts/extensions-vs-v4-hooks.md",
  "products/wallet": "wallet/README.md",
  "integration-guides/till-pattern": "concepts/architecture.md",
  "concepts/till-pattern": "concepts/architecture.md",
  "integration-guides/extensions": "concepts/extensions.md",
  "integration-guides/integrating-ekubo": "integration-guides/README.md",
  "integration-guides/reference": "reference/contracts/README.md",
  "integration-guides/reference/key-concepts": "concepts/key-concepts.md",
  "integration-guides/reference/reading-pool-price":
    "integration-guides/reading-pool-price.md",
  "integration-guides/reference/evm-contracts-v3":
    "reference/contracts/evm-v3.md",
  "integration-guides/reference/contract-addresses":
    "reference/contracts/evm-v2.md",
  "integration-guides/reference/starknet-contracts":
    "reference/contracts/starknet.md",
  "integration-guides/reference/governance-contracts":
    "reference/contracts/governance.md",
  "integration-guides/reference/ekubo-api": "reference/ekubo-api/README.md",
  "integration-guides/reference/ekubo-api/endpoints":
    "reference/ekubo-api/endpoints.md",
  "integration-guides/reference/quoter-api": "reference/quoter-api.md",
  "integration-guides/reference/audits": "reference/audits.md",
  "concepts/pool-math": "reference/pool-math.md",
  "concepts/price-representation": "reference/price-representation.md",
  "integration-guides/reference/math-1-pager": "reference/pool-math.md",
  "integration-guides/reference/price-representation":
    "reference/price-representation.md",
  "user-guides/ve33": "products/ve33.md",
  "user-guides/governance/README": "user-guides/governance.md",
  "user-guides/governance/ekubo-token": "user-guides/ekubo-token.md",
  "user-guides/governance/ekubo-inc": "products/governance.md",
};

export const retiredRoutes = {
  concepts: "/concepts/key-concepts/",
  reference: "/reference/contracts/",
  "user-guides": "/user-guides/add-liquidity/",

  "about-ekubo/background": "/concepts/key-concepts/",
  "about-ekubo/key-concepts": "/concepts/key-concepts/",
  "introduction/key-concepts": "/concepts/key-concepts/",
  "key-concepts": "/concepts/key-concepts/",
  "about-ekubo/roadmap": "/about-ekubo/vision/",
  "introduction/features": "/about-ekubo/features/",
  features: "/about-ekubo/features/",

  faq: "/",
  "about-ekubo/faq": "/",
  "introduction/faq": "/",
  "integration-guides/reference/frequently-asked-questions-faq": "/",

  "about-ekubo/starknet-defi-spring": "/products/rewards/",
  "integration-guides/reference/starknet-defi-spring": "/products/rewards/",
  "user-guides/incentives": "/products/rewards/",
  "user-guides/incentives/methodology": "/products/rewards/",
  "user-guides/incentives/starknet-defi-spring": "/products/rewards/",
  "user-guides/leaderboard": "/products/rewards/",
  "user-guides/swap": "/products/trading/",

  "integration-guides/core-interfaces": "/concepts/architecture/",
  "integration-guides/core-interfaces/using-the-till-pattern":
    "/concepts/architecture/",
  "integration-guides/reference/core-interfaces": "/concepts/architecture/",
  "integration-guides/reference/core-interfaces/using-the-till-pattern":
    "/concepts/architecture/",
  "integration-guides/reference/till-pattern": "/concepts/architecture/",

  "integration-guides/extensions/oracle": "/concepts/extensions/",
  "integrations/extensions": "/concepts/extensions/",
  "integrations/aggregators": "/integration-guides/aggregators/",
  "integration-guides/swapping/by-example": "/integration-guides/swapping/",

  "integration-guides/contract-addresses": "/reference/contracts/",
  "integration-guides/reference/error-codes": "/reference/contracts/",
  "integration-guides/reference/evm-contracts": "/reference/contracts/evm-v3/",
  "integration-guides/reference/evm-contracts-v2":
    "/reference/contracts/evm-v2/",
  "integration-guides/reference/ekubo-api/api-endpoints": "/api/",
};

export function fileToRoute(file) {
  if (file === "README.md") return "/";
  if (file.endsWith("/README.md")) {
    return `/${file.slice(0, -"README.md".length)}`;
  }
  return `/${file.slice(0, -".md".length)}/`;
}

const legacyTargetOverrides = {
  "reference/ekubo-api/README.md": "/api/",
  "reference/ekubo-api/endpoints.md": "/api/",
  "reference/quoter-api.md": "/api/#quoter",
  "concepts/extensions-vs-v4-hooks.md":
    "https://blog.ekubo.org/ekubo-extensions-vs-uniswap-v4-hooks/",
};

export function isExternalTarget(target) {
  return /^https?:\/\//.test(target);
}

export function fileToTarget(file) {
  return legacyTargetOverrides[file] ?? fileToRoute(file);
}

export function buildRedirects() {
  const redirects = new Map();
  const add = (source, target) => {
    if (source !== target) redirects.set(source, target);
  };

  for (const file of legacyFiles) {
    const route = fileToRoute(file);
    const target = fileToTarget(file);
    add(`/${file}`, target);
    add(`/${file}/`, target);
    if (file.endsWith("README.md")) {
      const readmePath = `/${file.slice(0, -".md".length)}`;
      add(readmePath, target);
      add(`${readmePath}/`, target);
    }
    if (route !== target) {
      add(route.replace(/\/$/, ""), target);
      add(route, target);
    }
  }

  for (const [source, targetFile] of Object.entries(movedRoutes)) {
    const target = fileToTarget(targetFile);
    for (const variant of [
      `/${source}`,
      `/${source}/`,
      `/${source}.md`,
      `/${source}.md/`,
    ]) {
      add(variant, target);
    }
  }

  for (const [source, target] of Object.entries(retiredRoutes)) {
    for (const variant of [
      `/${source}`,
      `/${source}/`,
      `/${source}.md`,
      `/${source}.md/`,
    ]) {
      add(variant, target);
    }
  }

  for (const [source, target] of [
    ["/api-explorer/ekubo", "/api/"],
    ["/api-explorer/quoter", "/api/#quoter"],
    ["/api/ekubo", "/api/"],
    ["/api/quoter", "/api/#quoter"],
  ]) {
    add(source, target);
    add(`${source}/`, target);
    add(`${source}/*`, target);
  }

  return redirects;
}
