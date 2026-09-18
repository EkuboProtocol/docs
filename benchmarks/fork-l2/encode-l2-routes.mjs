// Generates Yul-router calldata for the L2 fresh-pool WETH/USDC legs with the yul-router SDK.
import { encodeRoute } from "/home/sendmoodz/Work/ekubo/yul-router/sdk/src/index.ts";
import { writeFileSync } from "node:fs";
const RECIPIENT = "0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496"; // forge test contract address (asserted in the test)
function config(feeQ64, spacing) {
  // extension (20 bytes, zero) | fee (8 bytes) | 0x80000000 | spacing (4 bytes)
  const word = (BigInt(feeQ64) << 32n) | (0x80000000n | BigInt(spacing));
  return "0x" + word.toString(16).padStart(64, "0");
}
const chains = {
  base: {
    weth: "0x4200000000000000000000000000000000000006",
    usdc: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    fee: 55340232221128654n,
    spacing: 6000,
    priceWeiPerUnit: 1 / 2.464872103401631e-9,
  },
  arb: {
    weth: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    usdc: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    fee: 9223372036854775n,
    spacing: 1000,
    priceWeiPerUnit: 1 / 2.4603543652989017e-9,
  },
};
for (const [name, c] of Object.entries(chains)) {
  const cfg = config(c.fee, c.spacing);
  console.log(name, "config", cfg);
  for (const usdc of [50_000_000n, 100_000_000n, 1_000_000_000n]) {
    const expectedWei = BigInt(Math.floor(Number(usdc) * c.priceWeiPerUnit));
    const threshold = (expectedWei * 90n) / 100n;
    const data = encodeRoute({
      specifiedToken: c.usdc,
      calculatedToken: c.weth,
      specifiedAmount: usdc,
      calculatedAmountThreshold: threshold,
      recipient: RECIPIENT,
      hops: [
        {
          type: "core",
          poolKey: { token0: c.weth, token1: c.usdc, config: cfg },
        },
      ],
    });
    const f = `/tmp/l2bench/calldata/yul-route-${name}-${usdc / 1_000_000n}.hex`;
    writeFileSync(f, data + "\n");
    console.log(
      name,
      `${usdc / 1_000_000n} USDC`,
      "expectedWei",
      expectedWei.toString(),
      "threshold",
      threshold.toString(),
      "bytes",
      (data.length - 2) / 2,
    );
    console.log(data);
  }
}
