#!/usr/bin/env node
// Derives every figure on the Gas efficiency page from the raw snapshot and measurement
// files in this directory, so each percentage can be re-checked without a calculator.
// Run: node page-numbers.mjs
import { readFileSync } from "node:fs";
const j = (p) => JSON.parse(readFileSync(new URL(p, import.meta.url)));
const ek = j("./prod/snapshots/ProdEkuboTest.json");
const v3 = j("./prod/snapshots/ProdV3Test.json");
const v4 = j("./prod/snapshots/ProdV4Test.json");
const month = j(process.env.MONTH ?? "./pools-per-swap/results-30d.json");
const BASE = 21000;
const BLOCK_GAS = 60_000_000;
const tx = (snap, name) =>
  Number(snap[name]) +
  BASE +
  Number(snap[`${name} | calldata gas (4/16 per byte)`]);
const pct = (a, b) => ((100 * (b - a)) / b).toFixed(1);
const fmt = (n) => Math.round(n).toLocaleString("en-US");

// --- production routers and minimal lockers, 1 / 2 / 3 pools, fresh ERC20 pair
const legs = {
  "Ekubo, Yul router": [1, 2, 3].map((n) =>
    tx(
      ek,
      `prod ekubo Yul router ${n} pool${n > 1 ? "s" : ""} A->B${n > 1 ? "->C" : ""}${n > 2 ? "->D" : ""}`,
    ),
  ),
  "Ekubo, minimal locker": [1, 2, 3].map((n) =>
    tx(
      ek,
      `prod ekubo minimal locker ${n} pool${n > 1 ? "s" : ""} A->B${n > 1 ? "->C" : ""}${n > 2 ? "->D" : ""}`,
    ),
  ),
  "v4, Universal Router": [
    tx(v4, "prod v4 Universal Router V4_SWAP 1 pool A->B (Permit2)"),
  ],
  "v4, minimal locker": [1, 2, 3].map((n) =>
    tx(
      v4,
      `prod v4 minimal locker ${n} pool${n > 1 ? "s" : ""} A->B${n > 1 ? "->C" : ""}${n > 2 ? "->D" : ""}`,
    ),
  ),
  "v3, SwapRouter": [
    tx(v3, "prod v3 SwapRouter exactInputSingle 1 pool A->B"),
    tx(v3, "prod v3 SwapRouter exactInput 2 pools A->B->C"),
    tx(v3, "prod v3 SwapRouter exactInput 3 pools A->B->C->D"),
  ],
  "v3, minimal router": [1, 2, 3].map((n) =>
    tx(
      v3,
      `prod v3 minimal router ${n} pool${n > 1 ? "s" : ""} A->B${n > 1 ? "->C" : ""}${n > 2 ? "->D" : ""}`,
    ),
  ),
};
console.log(
  "Transaction gas (execution + 21,000 + calldata), fresh ERC20 pair, block",
  ek["prod fork block number"],
);
for (const [k, v] of Object.entries(legs))
  console.log(
    `  ${k.padEnd(24)} ${v.map(fmt).join(" / ")}   routes per 60M block: ${v.map((g) => Math.floor(BLOCK_GAS / g)).join(" / ")}`,
  );
const E = legs["Ekubo, Yul router"][0],
  V3 = legs["v3, SwapRouter"][0],
  V4 = legs["v4, Universal Router"][0],
  V4m = legs["v4, minimal locker"][0];
console.log(
  `  headline production: Ekubo ${fmt(E)} vs v3 ${fmt(V3)} (${pct(E, V3)}% less) vs v4 UR ${fmt(V4)} (${pct(E, V4)}% less); vs v4 minimal ${fmt(V4m)} (${pct(E, V4m)}% less)`,
);
const Em = legs["Ekubo, minimal locker"][0],
  V3m = legs["v3, minimal router"][0];
console.log(
  `  like-for-like minimal: Ekubo ${fmt(Em)} vs v4 ${fmt(V4m)} (${pct(Em, V4m)}%) vs v3 ${fmt(V3m)} (${pct(Em, V3m)}%)`,
);

// --- native ETH input
const nat = {
  ekubo: tx(ek, "prod ekubo Yul router 1 pool ETH->B"),
  v4: tx(v4, "prod v4 minimal locker 1 pool ETH->B"),
  v3: tx(
    v3,
    "prod v3 SwapRouter exactInputSingle 1 pool ETH(wrapped in flight)->B",
  ),
};
console.log(
  `  native ETH in: Ekubo ${fmt(nat.ekubo)} vs v4 minimal ${fmt(nat.v4)} (${pct(nat.ekubo, nat.v4)}%) vs v3 SwapRouter ${fmt(nat.v3)} (${pct(nat.ekubo, nat.v3)}%)`,
);

// --- marginal cost per extra pool (minimal routers, transaction gas incl. calldata growth) and blend
const marg = Object.fromEntries(
  Object.entries(legs)
    .filter(([, v]) => v.length === 3)
    .map(([k, v]) => [k, (v[2] - v[0]) / 2]),
);
console.log(
  "Marginal transaction gas per extra pool:",
  Object.entries(marg)
    .map(([k, v]) => `${k} ${fmt(v)}`)
    .join("; "),
);
const execMarg = {
  ekuboYul:
    (ek["prod ekubo Yul router 3 pools A->B->C->D"] -
      ek["prod ekubo Yul router 1 pool A->B"]) /
    2,
  ekuboMin:
    (ek["prod ekubo minimal locker 3 pools A->B->C->D"] -
      ek["prod ekubo minimal locker 1 pool A->B"]) /
    2,
  v4Min:
    (v4["prod v4 minimal locker 3 pools A->B->C->D"] -
      v4["prod v4 minimal locker 1 pool A->B"]) /
    2,
  v3Min:
    (v3["prod v3 minimal router 3 pools A->B->C->D"] -
      v3["prod v3 minimal router 1 pool A->B"]) /
    2,
  v3SR:
    (v3["prod v3 SwapRouter exactInput 3 pools A->B->C->D"] -
      v3["prod v3 SwapRouter exactInputSingle 1 pool A->B"]) /
    2,
};
console.log(
  "Marginal execution gas per extra pool:",
  Object.entries(execMarg)
    .map(([k, v]) => `${k} ${fmt(v)}`)
    .join("; "),
);

const avg = month.receipts.avgPoolsPerSwapTx;
const blend = (p) => ({
  ekubo:
    legs["Ekubo, minimal locker"][0] + (p - 1) * marg["Ekubo, minimal locker"],
  v4: legs["v4, minimal locker"][0] + (p - 1) * marg["v4, minimal locker"],
  v3: legs["v3, minimal router"][0] + (p - 1) * marg["v3, minimal router"],
});
console.log(
  `Blend (minimal routers), pools per swap -> Ekubo / v4 / v3 / saving vs v4 / vs v3`,
);
const rows = [avg, 1.0, 1.5, 2.0];
const savings = {};
for (const p of rows) {
  const b = blend(p);
  savings[p] = { v4: (b.v4 - b.ekubo) / b.v4, v3: (b.v3 - b.ekubo) / b.v3 };
  console.log(
    `  ${p}${p === avg ? " (measured)" : ""}: ${fmt(b.ekubo)} / ${fmt(b.v4)} / ${fmt(b.v3)} / ${pct(b.ekubo, b.v4)}% / ${pct(b.ekubo, b.v3)}%`,
  );
}

// --- pools per swap, 30-day sample
const r = month.receipts;
console.log(
  `30-day sample: ${month.window.blocksRead} blocks, stride ${month.window.stride}, ${month.window.fromIso} .. ${month.window.toIso}, blocks ${month.window.fromBlock}..${month.window.toBlock}`,
);
console.log(
  `  swap txs ${r.swapTxs.toLocaleString("en-US")}, avg ${avg} pools/swap tx, histogram`,
  Object.entries(r.histogram)
    .map(([k, v]) => `${k}: ${v.pct}%`)
    .join(", "),
  `gas share ${r.gasShare.pct}%`,
);
console.log(
  "  per family (txs / avg events of family per tx / avg total pools in those txs / gas share of window):",
);
for (const [f, s] of Object.entries(r.perFamily))
  console.log(
    `    ${f.padEnd(14)} ${String(s.txs).padStart(7)} ${s.avgEventsOfThisFamilyPerTx} ${s.avgTotalPoolsPerTxTouchingFamily} ${((100 * Number(s.gasOfTxsTouchingFamily)) / Number(r.gasShare.allTxGas)).toFixed(2)}%`,
  );
if (month.daily) {
  const d = Object.values(month.daily);
  console.log(
    `  daily avg pools/swap range ${Math.min(...d.map((x) => x.avgPoolsPerSwapTx))}..${Math.max(...d.map((x) => x.avgPoolsPerSwapTx))}, daily gas share range ${Math.min(...d.map((x) => x.swapTxGasSharePct))}%..${Math.max(...d.map((x) => x.swapTxGasSharePct))}%`,
  );
}
if (month.calldata)
  console.log(
    `  router-only (calldata-decoded) txs ${month.calldata.decodedTxs}, avg ${month.calldata.avgPoolsPerSwapTx}`,
  );

// --- chain-wide scenarios: share of block gas freed = share x saving
const shares = [
  ["4.2%, measured DEX-router burn, lower bound", 0.042],
  ["19.4%, ultrasound 'defi' bracket", 0.194],
  [
    `${r.gasShare.pct}%, swap-event txs in the 30-day sample`,
    r.gasShare.pct / 100,
  ],
  ["70%, stipulated AMM-trading upside (not measured)", 0.7],
];
const cols = [
  ["headline production 1 pool", { v3: (V3 - E) / V3, v4: (V4 - E) / V4 }],
  [`measured ${avg} pools`, savings[avg]],
  ["2.0 pools", savings[2]],
];
console.log(
  "Scenarios (range = v3 saving .. v4 saving, share of block gas freed):",
);
for (const [label, sh] of shares)
  console.log(
    `  ${label.padEnd(52)} ` +
      cols
        .map(
          ([c, s]) =>
            `${c}: ${(100 * sh * Math.min(s.v3, s.v4)).toFixed(1)}–${(100 * sh * Math.max(s.v3, s.v4)).toFixed(1)}%`,
        )
        .join(" | "),
  );
