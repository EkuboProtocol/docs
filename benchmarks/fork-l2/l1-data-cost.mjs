// Measures the L1 data component each L2 charges for the exact calldata of every measured leg,
// by asking the chain's own fee logic at the pinned block:
//   Base (OP Stack, Fjord+ estimator): GasPriceOracle.getL1Fee(unsignedTx) and getL1GasUsed(unsignedTx)
//     on the 0x42..0F predeploy, plus the L1Block scalars it reads (0x42..15), so the Fjord formula
//     can be re-derived by hand from the same inputs.
//   Arbitrum One (Nitro): NodeInterface.gasEstimateL1Component(to, false, data) (virtual contract
//     0xc8, eth_call only) and ArbGasInfo.getPricesInWei / getL1BaseFeeEstimate (precompile 0x6C).
// Usage: bun run l1-data-cost.mjs > l1-data-cost.json
import { readFileSync } from "node:fs";
import {
  serializeTransaction,
  encodeFunctionData,
  decodeFunctionResult,
  parseAbi,
} from "/home/sendmoodz/Work/ekubo/yul-router/sdk/node_modules/viem/_esm/index.js";

const SENDER = "0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496"; // the forge test contract, recipient in every route
const CHAINS = {
  base: {
    chainId: 8453,
    block: 51439900,
    rpcs: [
      "https://base-mainnet.public.blastapi.io",
      "https://mainnet.base.org",
    ],
    yulRouter: "0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748",
    v3Router: "0x2626664c2603336E57B271c5C0b26F421741e481", // SwapRouter02
    v4Locker: "0x2e234DAe75C793f67A35089C9d99245E1C58470b", // ForkSwapRouter deployed by the test (address only affects the tx `to` bytes)
    legs: [
      ["ekubo Yul router", "ekubo-yul-base", "yulRouter"],
      ["v3 SwapRouter02", "v3-SwapRouter02-base", "v3Router"],
      ["v4 minimal locker", "v4-minimal-locker-base", "v4Locker"],
    ],
  },
  arbitrum: {
    chainId: 42161,
    block: 506178800,
    rpcs: [
      "https://arbitrum-one.public.blastapi.io",
      "https://arb1.arbitrum.io/rpc",
    ],
    yulRouter: "0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748",
    v3Router: "0xE592427A0AEce92De3Edee1F18E0157C05861564", // classic SwapRouter
    v3Router02: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
    v4Locker: "0x2e234DAe75C793f67A35089C9d99245E1C58470b",
    legs: [
      ["ekubo Yul router", "ekubo-yul-arbitrum", "yulRouter"],
      ["v3 SwapRouter", "v3-SwapRouter-arbitrum", "v3Router"],
      ["v3 SwapRouter02", "v3-SwapRouter02-arbitrum", "v3Router02"],
      ["v4 minimal locker", "v4-minimal-locker-arbitrum", "v4Locker"],
    ],
  },
};
const SIZES = [50, 100, 1000];
// Realistic envelope for the unsigned EIP-1559 transaction whose bytes the estimators compress.
const TX = {
  nonce: 100,
  maxPriorityFeePerGas: 1_000_000n,
  maxFeePerGas: 10_000_000n,
  gas: 200_000n,
  value: 0n,
};

const oracleAbi = parseAbi([
  "function getL1Fee(bytes data) view returns (uint256)",
  "function getL1GasUsed(bytes data) view returns (uint256)",
  "function l1BaseFee() view returns (uint256)",
  "function blobBaseFee() view returns (uint256)",
  "function baseFeeScalar() view returns (uint32)",
  "function blobBaseFeeScalar() view returns (uint32)",
  "function isFjord() view returns (bool)",
  "function isJovian() view returns (bool)",
]);
const l1BlockAbi = parseAbi([
  "function daFootprintGasScalar() view returns (uint16)",
  "function number() view returns (uint64)",
]);
const nodeInterfaceAbi = parseAbi([
  "function gasEstimateL1Component(address to, bool contractCreation, bytes data) view returns (uint64 gasEstimateForL1, uint256 baseFee, uint256 l1BaseFeeEstimate)",
]);
const arbGasInfoAbi = parseAbi([
  "function getPricesInWei() view returns (uint256,uint256,uint256,uint256,uint256,uint256)",
  "function getL1BaseFeeEstimate() view returns (uint256)",
]);

let id = 1;
async function rpc(url, method, params) {
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: id++, method, params }),
    });
    const j = await res.json();
    if (!j.error) return j.result;
    if (
      attempt >= 8 ||
      !/rate limit|429|too many/i.test(JSON.stringify(j.error))
    )
      throw new Error(`${method} on ${url}: ${JSON.stringify(j.error)}`);
    await new Promise((r) => setTimeout(r, 1000 * 2 ** attempt)); // backoff on public-endpoint rate limits
  }
}
async function call(url, block, to, data, from) {
  const tx = { to, data };
  if (from) tx.from = from;
  return rpc(url, "eth_call", [tx, "0x" + block.toString(16)]);
}
async function read(url, block, to, abi, functionName, args = [], from) {
  const out = await call(
    url,
    block,
    to,
    encodeFunctionData({ abi, functionName, args }),
    from,
  );
  return decodeFunctionResult({ abi, functionName, data: out });
}
const hex = (f) => readFileSync(`calldata/${f}.hex`, "utf8").trim();
const bytesOf = (h) => (h.length - 2) / 2;
const calldataGas = (h) => {
  let g = 0;
  for (let i = 2; i < h.length; i += 2)
    g += h.slice(i, i + 2) === "00" ? 4 : 16;
  return g;
};

const out = {};
for (const [name, c] of Object.entries(CHAINS)) {
  const url = c.rpcs[0];
  const blockHex = "0x" + c.block.toString(16);
  const blk = await rpc(url, "eth_getBlockByNumber", [blockHex, false]);
  const l2BaseFee = BigInt(blk.baseFeePerGas);
  const chain = {
    chainId: c.chainId,
    block: c.block,
    blockHash: blk.hash,
    timestamp: Number(blk.timestamp),
    l2BaseFeeWei: l2BaseFee.toString(),
    rpc: url,
    crossCheckRpc: c.rpcs[1],
    legs: {},
  };
  if (name === "base") {
    const O = "0x420000000000000000000000000000000000000F",
      L = "0x4200000000000000000000000000000000000015";
    chain.oracle = {
      isFjord: await read(url, c.block, O, oracleAbi, "isFjord"),
      isJovian: await read(url, c.block, O, oracleAbi, "isJovian"),
      l1BaseFee: (
        await read(url, c.block, O, oracleAbi, "l1BaseFee")
      ).toString(),
      blobBaseFee: (
        await read(url, c.block, O, oracleAbi, "blobBaseFee")
      ).toString(),
      baseFeeScalar: Number(
        await read(url, c.block, O, oracleAbi, "baseFeeScalar"),
      ),
      blobBaseFeeScalar: Number(
        await read(url, c.block, O, oracleAbi, "blobBaseFeeScalar"),
      ),
      daFootprintGasScalar: Number(
        await read(url, c.block, L, l1BlockAbi, "daFootprintGasScalar"),
      ),
      l1OriginBlock: Number(await read(url, c.block, L, l1BlockAbi, "number")),
    };
  } else {
    const G = "0x000000000000000000000000000000000000006C";
    const p = await read(url, c.block, G, arbGasInfoAbi, "getPricesInWei");
    chain.arbGasInfo = {
      perL2Tx: p[0].toString(),
      weiPerL1CalldataByte: p[1].toString(),
      weiPerStorageAllocation: p[2].toString(),
      perArbGasBase: p[3].toString(),
      perArbGasCongestion: p[4].toString(),
      perArbGasTotal: p[5].toString(),
      l1BaseFeeEstimate: (
        await read(url, c.block, G, arbGasInfoAbi, "getL1BaseFeeEstimate")
      ).toString(),
    };
  }
  for (const [legName, file, toKey] of c.legs) {
    for (const size of SIZES) {
      const data = hex(`${file}-${size}`);
      const to = c[toKey];
      const unsigned = serializeTransaction({
        type: "eip1559",
        chainId: c.chainId,
        to,
        data,
        ...TX,
      });
      const leg = {
        to,
        calldataBytes: bytesOf(data),
        calldataGasL1Rule: calldataGas(data),
        unsignedTxBytes: bytesOf(unsigned),
      };
      if (name === "base") {
        const O = "0x420000000000000000000000000000000000000F";
        const l1Fee = await read(url, c.block, O, oracleAbi, "getL1Fee", [
          unsigned,
        ]);
        const l1GasUsed = await read(
          url,
          c.block,
          O,
          oracleAbi,
          "getL1GasUsed",
          [unsigned],
        );
        const l1Fee2 = await read(
          c.rpcs[1],
          c.block,
          O,
          oracleAbi,
          "getL1Fee",
          [unsigned],
        );
        const o = chain.oracle;
        const feeScaled =
          BigInt(o.baseFeeScalar) * 16n * BigInt(o.l1BaseFee) +
          BigInt(o.blobBaseFeeScalar) * BigInt(o.blobBaseFee);
        // l1Fee = estimatedSizeScaled * feeScaled / 1e12  =>  estimatedSize bytes = l1Fee * 1e12 / feeScaled / 1e6
        const estimatedSizeScaled = (l1Fee * 10n ** 12n) / feeScaled;
        Object.assign(leg, {
          l1FeeWei: l1Fee.toString(),
          l1FeeWeiCrossCheck: l1Fee2.toString(),
          l1GasUsed: l1GasUsed.toString(),
          estimatedCompressedBytes: Number(estimatedSizeScaled) / 1e6,
          daFootprintGas:
            Math.floor(Number(estimatedSizeScaled) / 1e6) *
            o.daFootprintGasScalar,
          l1FeeInL2GasUnits: Number(l1Fee) / Number(l2BaseFee),
        });
      } else {
        const N = "0x00000000000000000000000000000000000000C8";
        const r = await read(
          url,
          c.block,
          N,
          nodeInterfaceAbi,
          "gasEstimateL1Component",
          [to, false, data],
          SENDER,
        );
        const r2 = await read(
          c.rpcs[1],
          c.block,
          N,
          nodeInterfaceAbi,
          "gasEstimateL1Component",
          [to, false, data],
          SENDER,
        );
        const gasForL1 = BigInt(r[0]);
        const posterCostWei = gasForL1 * BigInt(r[1]);
        // units = 16 * brotli-compressed bytes of the (fake-signed) tx; gas estimation pads them by 256 units and 1% (nitro arbos/l1pricing)
        const paddedUnits = Number(posterCostWei) / Number(r[2]);
        Object.assign(leg, {
          gasEstimateForL1: gasForL1.toString(),
          gasEstimateForL1CrossCheck: r2[0].toString(),
          l2BaseFeeFromNode: r[1].toString(),
          l1BaseFeeEstimate: r[2].toString(),
          posterCostWei: posterCostWei.toString(),
          paddedL1GasUnits: Math.round(paddedUnits),
        });
      }
      chain.legs[`${legName} ${size} USDC`] = leg;
    }
  }
  out[name] = chain;
}
console.log(JSON.stringify(out, null, 2));
