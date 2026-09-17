#!/usr/bin/env node
// Measures how many pools a mainnet swap transaction touches.
//
// Two independent measurements over the same block window, both from a public
// JSON-RPC endpoint (no Dune / indexer needed):
//
//   1. receipts  — eth_getBlockReceipts per block. Counts pool-level swap events
//                  per successful transaction (topic0 in the families below, plus
//                  Ekubo Core's topic-less 116-byte swap log). This covers every
//                  flow: routers, aggregators, MEV bundles, direct pool calls. Logs
//                  exist only for successful transactions, so failed fills are
//                  excluded by construction.
//   2. calldata  — eth_getBlockByNumber(full txs). For transactions sent to the
//                  verified router contracts below, decodes the hop count from the
//                  calldata (Universal Router commands, SwapRouter02 / SwapRouter
//                  exactInput paths, 1inch unoswapN). Router flow only.
//
// Usage: node measure.mjs [--blocks N] [--to BLOCK] [--rpc URL] [--out FILE]

import { writeFileSync } from "node:fs";

const args = Object.fromEntries(
  process.argv
    .slice(2)
    .map((a, i, arr) => (a.startsWith("--") ? [a.slice(2), arr[i + 1]] : null))
    .filter(Boolean),
);
const RPC = args.rpc ?? "https://ethereum-rpc.publicnode.com";
const BLOCKS = Number(args.blocks ?? 200);
const OUT = args.out ?? "results.json";

// Event signatures. Every signature was read from the protocol's own source (repo path in
// the comment) and hashed with `cast keccak` (Foundry 1.8.3); none is memorized.
const FAMILIES = {
  // Uniswap v3-core IUniswapV3PoolEvents: Swap(address,address,int256,int256,uint160,uint128,int24).
  // Shared by SushiSwap v3 and KyberSwap Elastic (identical parameter types), so those land here too.
  "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67": "univ3",
  // Uniswap v2-core: Swap(address,uint256,uint256,uint256,uint256,address) — v2 and every fork (Sushi, PancakeSwap v2, Fraxswap, ...)
  "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822":
    "univ2-family",
  // curvefi/stableswap-ng CurveStableSwapNG.vy (and the classic plain/meta pools): TokenExchange(address,int128,uint256,int128,uint256)
  "0x8b3e96f2b889fa771c53c981b40daf005f63f637f1869f707052d15a3dd97140": "curve",
  // same, TokenExchangeUnderlying(address,int128,uint256,int128,uint256)
  "0xd013ca23e77a65003c2c659c5442c00c805371b7fc1ebd4c206c41d1536bd90b": "curve",
  // curvefi/curve-crypto-contract CurveCryptoSwap2ETH.vy (crypto v2 pools): TokenExchange(address,uint256,uint256,uint256,uint256)
  "0xb2e76ae99761dc136e598d4a629bb347eccb9532a5f8bbd72e18467c3c34cc98": "curve",
  // curvefi/tricrypto-ng CurveTricryptoOptimizedWETH.vy and twocrypto-ng Twocrypto.vy:
  // TokenExchange(address,uint256,uint256,uint256,uint256,uint256,uint256)
  "0x143f1f8e861fbdeddd5b46e844b7d3ac7b86a122f36e8c463859ee6811b1f29c": "curve",
  // Uniswap v4-core IPoolManager: Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)
  "0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f": "univ4",
  // balancer-v2-monorepo pkg/interfaces/contracts/vault/IVault.sol: Swap(bytes32,address,address,uint256,uint256)
  "0x2170c741c41531aec20e7c107c24eecfdd15e69c9bb0a8dd37b1840b9e0b207b":
    "balancer-v2",
  // balancer-v3-monorepo pkg/interfaces/contracts/vault/IVaultEvents.sol:
  // Swap(address,address,address,uint256,uint256,uint256,uint256)
  "0x0874b2d545cb271cdbda4e093020c452328b24af12382ed62c4d00f5c26709db":
    "balancer-v3",
  // maverickprotocol/maverick-v1-interfaces IPool.sol: Swap(address,address,bool,bool,uint256,uint256,int32)
  "0x3b841dc9ab51e3104bda4f61b41e4271192d22cd19da5ee6e292dc8e2744f713":
    "maverick-v1",
  // maverickprotocol/v2-common IMaverickV2Pool.sol: PoolSwap(address,address,SwapParams,uint256,uint256)
  // with SwapParams = (uint256 amount, bool tokenAIn, bool exactOutput, int32 tickLimit)
  "0x103ed084e94a44c8f5f6ba8e3011507c41063177e29949083c439777d8d63f60":
    "maverick-v2",
  // pancakeswap/pancake-v3-contracts IPancakeV3PoolEvents.sol:
  // Swap(address,address,int256,int256,uint160,uint128,int24,uint128,uint128) — differs from v3 by the two protocol-fee words
  "0x19b47279256b2a23a1665c810c8d55a1758940ee09377d4f8d26497a3577dc83":
    "pancake-v3",
  // DODOEX/contractV2 DVMTrader.sol / DPPTrader.sol / DSPTrader.sol: DODOSwap(address,address,uint256,uint256,address,address)
  "0xc2c0245e056d5fb095f04cd6373bc770802ebd1e6c918eb78fdef843cdb37b0f": "dodo",
  // DODOEX/dodo-smart-contract Trader.sol (v1): SellBaseToken(address,uint256,uint256)
  "0xd8648b6ac54162763c86fd54bf2005af8ecd2f9cb273a5775921fd7f91e17b2d": "dodo",
  // same (v1): BuyBaseToken(address,uint256,uint256)
  "0xe93ad76094f247c0dafc1c61adc2187de1ac2738f7a3b49cb20b2263420251a3": "dodo",
  // bancorprotocol/contracts-v3 BancorNetwork.sol:
  // TokensTraded(bytes32,address,address,uint256,uint256,uint256,uint256,uint256,address), one per hop
  "0x5c02c2bb2d1d082317eb23916ca27b3e7c294398b60061a2ad54f1c3c018c318":
    "bancor-v3",
  // bancorprotocol/carbon-contracts Strategies.sol: TokensTraded(address,address,address,uint256,uint256,uint128,bool)
  "0x95f3b01351225fea0e69a46f68b164c9dea10284f12cd4a907ce66510ab7af6a":
    "bancor-carbon",
  // bancorprotocol/contracts-solidity converter/interfaces/IConverter.sol (v2.1 converters):
  // Conversion(address,address,address,uint256,uint256,int256)
  "0x276856b36cbc45526a0ba64f44611557a2a8b68662c5388e9fe6d72e86e1c8cb":
    "bancor-v2",
  // Instadapp/fluid-contracts-public protocols/dex/poolT1/coreModule/events.sol: Swap(bool,uint256,uint256,address)
  "0xdc004dbca4ef9c966218431ee5d9133d337ad018dd5b5c5493722803f75c64f7": "fluid",
  // aerodrome-finance/contracts IPool.sol (Solidly-style pairs: Aerodrome, Velodrome, Solidly forks):
  // Swap(address,address,uint256,uint256,uint256,uint256) — a different topic from the v2 family
  "0xb3e2773606abfd36b5bd91394b3a54d1398336c65005baf7bf7a05efeffaf75b":
    "solidly-style",
};

// Ekubo Core emits its swap record with `log0` (no topics) and exactly 116 bytes of data:
// 20-byte locker, 32-byte poolId, 32-byte balance update, 32-byte pool state
// (EkuboProtocol/evm-contracts v3.2.0 src/Core.sol, `log0(o, 116)`). Every other Core
// event is a normal topic-carrying `emit`, so "zero topics + 116 bytes from Core" is exact.
const EKUBO_CORE = "0x00000000000014aa86c5d3c41765bb24e11bd701";
const EKUBO_SWAP_DATA_HEX_LEN = 2 + 116 * 2;

// Router contracts. Each address is verified at startup: the deployed bytecode must
// contain the 4-byte selectors listed (a memorized address that fails this check aborts the run).
const ROUTERS = {
  "0x66a9893cc07d91d95644aedd05d03f95e1dba8af": {
    name: "Universal Router (v2, 2025)",
    kind: "ur",
    selectors: ["3593564c"],
  },
  "0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad": {
    name: "Universal Router (v1.2, 2023)",
    kind: "ur",
    selectors: ["3593564c"],
  },
  "0x68b3465833fb72a70ecdf485e0e4c7bd8665fc45": {
    name: "SwapRouter02",
    kind: "sr02",
    selectors: ["b858183f", "5ae401dc"],
  },
  "0xe592427a0aece92de3edee1f18e0157c05861564": {
    name: "SwapRouter (v3 classic)",
    kind: "sr",
    selectors: ["c04b8d59"],
  },
  "0x7a250d5630b4cf539739df2c5dacb4c659f2488d": {
    name: "Uniswap v2 Router02",
    kind: "v2r",
    selectors: ["38ed1739"],
  },
  "0x111111125421ca6dc452d289314280a0f8842a65": {
    name: "1inch AggregationRouter v6",
    kind: "oneinch",
    selectors: ["07ed2379", "83800a8e"],
  },
  // Third Universal Router deployment seen as a top gas consumer in the window; Sourcify
  // full-matches it to UniswapRouter contracts/UniversalRouter.sol.
  "0x4c82d1fbfe28c977cbb58d8c7ff8fcf9f70a2cca": {
    name: "Universal Router (2026 deployment)",
    kind: "ur",
    selectors: ["3593564c"],
  },
  // Ekubo's production Yul router has no ABI selectors (calldata is packed route data),
  // so it is verified by the Core address embedded in its bytecode instead. Hop counts are
  // not decoded from its calldata; Ekubo pools are counted from Core's own swap logs.
  "0x7b2aa7ecc0b5936b7c52e6259a19c3ba557d0748": {
    name: "Ekubo Yul router",
    kind: "ekubo-yul",
    selectors: [],
    bytecodeContains: [EKUBO_CORE.slice(2)],
  },
};

let rpcCalls = 0;
async function rpc(method, params) {
  for (let attempt = 0; ; attempt++) {
    try {
      rpcCalls++;
      const res = await fetch(RPC, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
      });
      const body = await res.json();
      if (body.error)
        throw new Error(`${method}: ${JSON.stringify(body.error)}`);
      if (body.result == null) throw new Error(`${method}: null result`);
      return body.result;
    } catch (e) {
      if (attempt >= 8) throw e;
      const wait = 500 * 2 ** attempt;
      await new Promise((r) => setTimeout(r, wait));
    }
  }
}

// ---- minimal ABI helpers -----------------------------------------------------
const word = (hex, i) => hex.slice(i * 64, i * 64 + 64);
const num = (hex, i) => Number(BigInt("0x" + word(hex, i)));
// dynamic `bytes` or `bytes[]` element at word index i inside `hex` (already stripped of selector)
function dynBytes(hex, base, i) {
  const off = num(hex.slice(base * 2), i);
  const start = base + off;
  const len = Number(BigInt("0x" + hex.slice(start * 2, start * 2 + 64)));
  return hex.slice(start * 2 + 64, start * 2 + 64 + len * 2);
}
function dynArray(hex, base, i) {
  const off = num(hex.slice(base * 2), i);
  const start = base + off;
  const len = Number(BigInt("0x" + hex.slice(start * 2, start * 2 + 64)));
  return { start: start + 32, len };
}
function bytesArray(hex, base, i) {
  const { start, len } = dynArray(hex, base, i);
  const out = [];
  for (let k = 0; k < len; k++) out.push(dynBytes(hex, start, k));
  return out;
}
const v3PathHops = (path) => (path.length / 2 - 20) / 23; // 20 + 23n bytes

// Universal Router command bytes (Commands.sol), low 6 bits.
const UR = {
  V3_SWAP_EXACT_IN: 0x00,
  V3_SWAP_EXACT_OUT: 0x01,
  V2_SWAP_EXACT_IN: 0x08,
  V2_SWAP_EXACT_OUT: 0x09,
  V4_SWAP: 0x10,
};
// v4 router actions (Actions.sol)
const V4 = {
  SWAP_EXACT_IN_SINGLE: 0x06,
  SWAP_EXACT_IN: 0x07,
  SWAP_EXACT_OUT_SINGLE: 0x08,
  SWAP_EXACT_OUT: 0x09,
};

// Pools touched by one Universal Router command; null when the command is not a swap.
function urCommandPools(cmd, inp) {
  if (cmd === UR.V3_SWAP_EXACT_IN || cmd === UR.V3_SWAP_EXACT_OUT) {
    // (address recipient, uint256 amount, uint256 amountLimit, bytes path, bool payerIsUser)
    return v3PathHops(dynBytes(inp, 0, 3));
  }
  if (cmd === UR.V2_SWAP_EXACT_IN || cmd === UR.V2_SWAP_EXACT_OUT) {
    // (address recipient, uint256 amount, uint256 amountLimit, address[] path, bool payerIsUser)
    return dynArray(inp, 0, 3).len - 1;
  }
  if (cmd === UR.V4_SWAP) return v4SwapPools(inp);
  return null;
}

// V4_SWAP input: (bytes actions, bytes[] params)
function v4SwapPools(inp) {
  const actions = dynBytes(inp, 0, 0);
  const params = bytesArray(inp, 0, 1);
  let pools = null;
  for (let a = 0; a < actions.length / 2; a++) {
    const n = v4ActionPools(
      parseInt(actions.slice(a * 2, a * 2 + 2), 16),
      params[a],
    );
    if (n != null) pools = (pools ?? 0) + n;
  }
  return pools;
}

function v4ActionPools(act, p) {
  if (act === V4.SWAP_EXACT_IN_SINGLE || act === V4.SWAP_EXACT_OUT_SINGLE)
    return 1;
  if (act === V4.SWAP_EXACT_IN || act === V4.SWAP_EXACT_OUT) {
    // abi.encode(ExactInputParams): one head word (offset) then struct: currency, path offset, amount, amountMin
    const structStart = num(p, 0);
    const pathOff = num(p.slice(structStart * 2), 1);
    return num(p.slice((structStart + pathOff) * 2), 0); // PathKey[] length
  }
  return null;
}

function decodeUR(input) {
  const sel = input.slice(2, 10);
  if (sel !== "3593564c" && sel !== "24856bc3") return null;
  const hex = input.slice(10);
  const commands = dynBytes(hex, 0, 0);
  const inputs = bytesArray(hex, 0, 1);
  let pools = null;
  for (let k = 0; k < commands.length / 2; k++) {
    const cmd = parseInt(commands.slice(k * 2, k * 2 + 2), 16) & 0x3f;
    const n = urCommandPools(cmd, inputs[k]);
    if (n != null) pools = (pools ?? 0) + n;
  }
  return pools;
}

// SwapRouter02 / classic SwapRouter selectors -> how to read the pool count.
const SR_PATH = new Set([
  "b858183f", // SwapRouter02 exactInput((bytes path,address,uint256,uint256))
  "09b81346", // SwapRouter02 exactOutput
  "c04b8d59", // SwapRouter exactInput((bytes,address,uint256,uint256,uint256))
  "f28c0498", // SwapRouter exactOutput
]);
const SR_SINGLE = new Set([
  "04e45aaf", // SwapRouter02 exactInputSingle
  "5023b4df", // SwapRouter02 exactOutputSingle
  "414bf389", // SwapRouter exactInputSingle
  "db3e2198", // SwapRouter exactOutputSingle
]);
const SR_V2 = new Set([
  "472b43f3", // SwapRouter02 swapExactTokensForTokens(uint256,uint256,address[],address)
  "42712a67", // SwapRouter02 swapTokensForExactTokens
]);

function decodeSwapRouterCall(callHex) {
  const sel = callHex.slice(0, 8);
  const hex = callHex.slice(8);
  if (SR_PATH.has(sel)) return v3PathHops(dynBytes(hex, num(hex, 0), 0));
  if (SR_SINGLE.has(sel)) return 1;
  if (SR_V2.has(sel)) return dynArray(hex, 0, 2).len - 1;
  return null;
}

function decodeSwapRouter(input) {
  const sel = input.slice(2, 10);
  const hex = input.slice(10);
  let calls;
  if (sel === "5ae401dc" || sel === "1f0464d1")
    calls = bytesArray(hex, 0, 1); // multicall(uint256|bytes32, bytes[])
  else if (sel === "ac9650d8")
    calls = bytesArray(hex, 0, 0); // multicall(bytes[])
  else calls = [input.slice(2)];
  let pools = 0;
  let found = false;
  for (const c of calls) {
    const n = decodeSwapRouterCall(c);
    if (n != null) {
      pools += n;
      found = true;
    }
  }
  return found ? pools : null;
}

function decodeV2Router(input) {
  const sel = input.slice(2, 10);
  const hex = input.slice(10);
  // swapExact*/swap*ForExact* on Router02: path is arg index 2 (amountIn, amountOutMin, path, to, deadline)
  // or index 1 for the payable ETH-input variants (amountOutMin, path, to, deadline)
  const idx2 = new Set([
    "38ed1739",
    "8803dbee",
    "18cbafe5",
    "4a25d94a",
    "5c11d795",
    "791ac947",
  ]);
  const idx1 = new Set(["7ff36ab5", "fb3bdb41", "b6f9de95"]);
  if (idx2.has(sel)) return dynArray(hex, 0, 2).len - 1;
  if (idx1.has(sel)) return dynArray(hex, 0, 1).len - 1;
  return null;
}

function decodeOneInch(input) {
  const sel = input.slice(2, 10);
  const table = {
    "83800a8e": 1,
    "8770ba91": 2,
    19367472: 3,
    a76dfc3b: 1,
    "89af926a": 2,
    "188ac35d": 3,
  };
  if (sel in table) return table[sel];
  if (sel === "07ed2379") return "opaque"; // generic swap(executor, desc, data): hop count is inside executor data
  return null;
}

function decodeRouterTx(kind, input) {
  try {
    if (kind === "ekubo-yul") return "opaque"; // packed route calldata, not decoded here
    if (kind === "ur") return decodeUR(input);
    if (kind === "sr02" || kind === "sr") return decodeSwapRouter(input);
    if (kind === "v2r") return decodeV2Router(input);
    if (kind === "oneinch") return decodeOneInch(input);
  } catch {
    return null;
  }
  return null;
}

// ---- main ---------------------------------------------------------------------
const latest = Number(BigInt(await rpc("eth_blockNumber", [])));
const toBlock = Number(args.to ?? latest - 12); // stay behind the head to avoid reorgs
const fromBlock = toBlock - BLOCKS + 1;

for (const [addr, r] of Object.entries(ROUTERS)) {
  const code = await rpc("eth_getCode", [addr, "latest"]);
  for (const s of [...r.selectors, ...(r.bytecodeContains ?? [])]) {
    if (!code.includes(s))
      throw new Error(`${r.name} at ${addr}: bytecode lacks ${s}`);
  }
  r.codeBytes = (code.length - 2) / 2;
}
const ekuboCoreCodeBytes =
  ((await rpc("eth_getCode", [EKUBO_CORE, "latest"])).length - 2) / 2;
if (!ekuboCoreCodeBytes) throw new Error("Ekubo Core has no code");

const receipts = {
  txs: 0,
  failedSwapTxs: 0,
  hist: {},
  perFamily: {},
  gasUsedSwapTxs: 0n,
  gasUsedAll: 0n,
  sumPools: 0,
  ekuboCoreOtherTopiclessLogs: 0, // sanity: Core topic-less logs that are not 116 bytes (expected 0)
  allTxs: 0,
  successfulTxs: 0,
};
const calldata = {
  txs: 0,
  hist: {},
  perRouter: {},
  sumPools: 0,
  opaque: 0,
  undecoded: 0,
  failed: 0,
  crossCheck: { compared: 0, equal: 0, calldataLower: 0, calldataHigher: 0 },
  undecodedSelectors: {},
};
const bump = (h, k) => (h[k] = (h[k] ?? 0) + 1);
const fam = (name) =>
  (receipts.perFamily[name] ??= {
    txs: 0,
    events: 0,
    poolsInThoseTxs: 0,
    gas: 0n,
    emitters: {},
  });
const routerStat = (name) =>
  (calldata.perRouter[name] ??= {
    txs: 0,
    sumPools: 0,
    hist: {},
    opaque: 0,
    undecoded: 0,
    failed: 0,
    crossCheck: { compared: 0, equal: 0, calldataLower: 0, calldataHigher: 0 },
    mismatchSamples: [],
  });

let firstTs, lastTs;
const CONC = 4;
const blocks = Array.from({ length: BLOCKS }, (_, i) => fromBlock + i);
let next = 0;
// Count pool-level swap events in one receipt; returns { counts by family, total }.
function swapEventsIn(receipt) {
  const counts = {};
  const emitters = {};
  let total = 0;
  for (const log of receipt.logs) {
    let f;
    if (log.topics.length === 0) {
      if (log.address.toLowerCase() !== EKUBO_CORE) continue;
      if (log.data.length !== EKUBO_SWAP_DATA_HEX_LEN) {
        receipts.ekuboCoreOtherTopiclessLogs++;
        continue;
      }
      f = "ekubo";
    } else {
      f = FAMILIES[log.topics[0]];
      if (!f) continue;
    }
    counts[f] = (counts[f] ?? 0) + 1;
    (emitters[f] ??= {})[log.address.toLowerCase()] = 1;
    total++;
  }
  return { counts, emitters, total };
}

// Measurement 1: tally one block's receipts. Returns tx hash -> pool count for the cross-check.
function tallyReceipts(rcpts) {
  const eventPools = new Map();
  for (const r of rcpts) {
    receipts.gasUsedAll += BigInt(r.gasUsed);
    receipts.allTxs++;
    if (r.status === "0x1") receipts.successfulTxs++;
    const { counts, emitters, total } = swapEventsIn(r);
    if (!total) continue;
    if (r.status !== "0x1") {
      receipts.failedSwapTxs++; // cannot happen (failed txs emit no logs) — kept as a sanity counter
      continue;
    }
    receipts.txs++;
    receipts.sumPools += total;
    eventPools.set(r.transactionHash, total);
    receipts.gasUsedSwapTxs += BigInt(r.gasUsed);
    bump(receipts.hist, Math.min(total, 4));
    for (const [f, c] of Object.entries(counts)) {
      const s = fam(f);
      s.txs++;
      s.events += c;
      s.poolsInThoseTxs += total;
      s.gas += BigInt(r.gasUsed);
      for (const a of Object.keys(emitters[f])) bump(s.emitters, a);
    }
  }
  return eventPools;
}

function crossCheck(n, ev, rs, hash) {
  if (ev == null) return;
  for (const cc of [calldata.crossCheck, rs.crossCheck]) {
    cc.compared++;
    if (ev === n) cc.equal++;
    else if (n < ev) cc.calldataLower++;
    else cc.calldataHigher++;
  }
  if (ev !== n && rs.mismatchSamples.length < 5)
    rs.mismatchSamples.push({ hash, calldata: n, events: ev });
}

// Measurement 2: one successful transaction sent to a verified router.
function tallyRouterTx(router, tx, eventPools) {
  const rs = routerStat(router.name);
  const n = decodeRouterTx(router.kind, tx.input);
  if (n === "opaque") {
    calldata.opaque++;
    rs.opaque++;
    return;
  }
  if (n == null || n <= 0) {
    calldata.undecoded++;
    rs.undecoded++;
    bump(
      calldata.undecodedSelectors,
      `${router.name}:${tx.input.slice(0, 10)}`,
    );
    return;
  }
  calldata.txs++;
  calldata.sumPools += n;
  bump(calldata.hist, Math.min(n, 4));
  rs.txs++;
  rs.sumPools += n;
  bump(rs.hist, Math.min(n, 4));
  crossCheck(n, eventPools.get(tx.hash), rs, tx.hash);
}

function tallyBlock(block, rcpts) {
  const status = new Map(
    rcpts.map((r) => [r.transactionHash, r.status === "0x1"]),
  );
  const eventPools = tallyReceipts(rcpts);
  for (const tx of block.transactions) {
    const router = ROUTERS[(tx.to ?? "").toLowerCase()];
    if (!router) continue;
    if (!status.get(tx.hash)) {
      // keep the same population as the receipts measurement: successful txs only
      calldata.failed++;
      routerStat(router.name).failed++;
      continue;
    }
    tallyRouterTx(router, tx, eventPools);
  }
}

async function worker() {
  while (next < blocks.length) {
    const bn = blocks[next++];
    const tag = "0x" + bn.toString(16);
    const [block, rcpts] = await Promise.all([
      rpc("eth_getBlockByNumber", [tag, true]),
      rpc("eth_getBlockReceipts", [tag]),
    ]);
    const ts = Number(BigInt(block.timestamp));
    if (bn === fromBlock) firstTs = ts;
    if (bn === toBlock) lastTs = ts;
    tallyBlock(block, rcpts);
    if ((bn - fromBlock) % 50 === 0)
      process.stderr.write(`block ${bn} (${bn - fromBlock + 1}/${BLOCKS})\n`);
  }
}
await Promise.all(Array.from({ length: CONC }, worker));

const pct = (n, d) => (d ? +((100 * n) / d).toFixed(2) : 0);
const histShare = (h, n) =>
  Object.fromEntries(
    [1, 2, 3, 4].map((k) => [
      k === 4 ? "4+" : String(k),
      { txs: h[k] ?? 0, pct: pct(h[k] ?? 0, n) },
    ]),
  );

const out = {
  rpc: RPC,
  window: {
    fromBlock,
    toBlock,
    blocks: BLOCKS,
    fromTimestamp: firstTs,
    toTimestamp: lastTs,
    fromIso: new Date(firstTs * 1000).toISOString(),
    toIso: new Date(lastTs * 1000).toISOString(),
  },
  rpcCalls,
  families: FAMILIES,
  ekuboCore: {
    address: EKUBO_CORE,
    codeBytes: ekuboCoreCodeBytes,
    swapLog:
      "log0, no topics, 116 bytes of data (locker, poolId, balanceUpdate, stateAfter)",
  },
  routers: Object.fromEntries(
    Object.entries(ROUTERS).map(([a, r]) => [
      a,
      {
        name: r.name,
        kind: r.kind,
        verifiedSelectors: r.selectors,
        verifiedBytecodeContains: r.bytecodeContains ?? [],
        codeBytes: r.codeBytes,
      },
    ]),
  ),
  receipts: {
    method:
      "eth_getBlockReceipts; successful txs with >=1 pool-level swap event; pools = number of such events in the tx",
    swapTxs: receipts.txs,
    sumPools: receipts.sumPools,
    failedSwapTxsSeen: receipts.failedSwapTxs,
    avgPoolsPerSwapTx: +(receipts.sumPools / receipts.txs).toFixed(3),
    histogram: histShare(receipts.hist, receipts.txs),
    ekuboCoreOtherTopiclessLogs: receipts.ekuboCoreOtherTopiclessLogs,
    allTxs: receipts.allTxs,
    successfulTxs: receipts.successfulTxs,
    perFamily: Object.fromEntries(
      Object.entries(receipts.perFamily)
        .sort((a, b) => b[1].txs - a[1].txs)
        .map(([f, s]) => [
          f,
          {
            txs: s.txs,
            events: s.events,
            avgEventsOfThisFamilyPerTx: +(s.events / s.txs).toFixed(3),
            avgTotalPoolsPerTxTouchingFamily: +(
              s.poolsInThoseTxs / s.txs
            ).toFixed(3),
            gasOfTxsTouchingFamily: s.gas.toString(),
            // distinct emitting contracts and the busiest ones (txs in which each emitted)
            emitters: Object.keys(s.emitters).length,
            topEmitters: Object.fromEntries(
              Object.entries(s.emitters)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 5),
            ),
          },
        ]),
    ),
    familiesWithNoEvents: [...new Set(Object.values(FAMILIES)), "ekubo"].filter(
      (f) => !receipts.perFamily[f],
    ),
    gasShare: {
      swapTxGas: receipts.gasUsedSwapTxs.toString(),
      allTxGas: receipts.gasUsedAll.toString(),
      pct: pct(Number(receipts.gasUsedSwapTxs), Number(receipts.gasUsedAll)),
    },
  },
  calldata: {
    method:
      "eth_getBlockByNumber(full); successful txs to the verified routers; pools decoded from calldata",
    decodedTxs: calldata.txs,
    sumPools: calldata.sumPools,
    avgPoolsPerSwapTx: +(calldata.sumPools / calldata.txs).toFixed(3),
    histogram: histShare(calldata.hist, calldata.txs),
    opaqueTxs: calldata.opaque,
    undecodedTxs: calldata.undecoded,
    failedTxs: calldata.failed,
    crossCheckAgainstReceipts: calldata.crossCheck,
    undecodedSelectors: Object.fromEntries(
      Object.entries(calldata.undecodedSelectors).sort((a, b) => b[1] - a[1]),
    ),
    perRouter: Object.fromEntries(
      Object.entries(calldata.perRouter).map(([n, s]) => [
        n,
        {
          decodedTxs: s.txs,
          avgPools: s.txs ? +(s.sumPools / s.txs).toFixed(3) : null,
          histogram: histShare(s.hist, s.txs),
          opaque: s.opaque,
          undecoded: s.undecoded,
          failed: s.failed,
          crossCheckAgainstReceipts: s.crossCheck,
          mismatchSamples: s.mismatchSamples,
        },
      ]),
    ),
  },
};
writeFileSync(OUT, JSON.stringify(out, null, 2) + "\n");
console.log(JSON.stringify(out, null, 2));
