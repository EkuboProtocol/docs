// Generates the Yul-router calldata for ProdEkubo.t.sol with the yul-router SDK.
// Token addresses and the pool config are the constants in test/ProdCommon.sol and
// test/ProdEkubo.t.sol; the recipient is the forge test contract address.
// Run: bun encode-prod-routes.mjs   (writes calldata/ekubo-yul-*.hex)
import { writeFileSync } from "node:fs";
import { encodeRoute } from "/home/sendmoodz/Work/ekubo/yul-router/sdk/src/index.ts";

const A = "0x1111111111111111111111111111111111111111";
const B = "0x2222222222222222222222222222222222222222";
const C = "0x3333333333333333333333333333333333333333";
const D = "0x4444444444444444444444444444444444444444";
const NATIVE = "0x0000000000000000000000000000000000000000";
const config = "0x000000000000000000000000000000000000000000c49ba5e353f7ce80001770"; // 0.3%, spacing 6000, no extension
const recipient = "0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496";
const hop = (token0, token1) => ({ type: "core", poolKey: { token0, token1, config } });

const routes = {
  "ekubo-yul-1pool": { specifiedToken: A, calculatedToken: B, hops: [hop(A, B)] },
  "ekubo-yul-2pools": { specifiedToken: A, calculatedToken: C, hops: [hop(A, B), hop(B, C)] },
  "ekubo-yul-3pools": { specifiedToken: A, calculatedToken: D, hops: [hop(A, B), hop(B, C), hop(C, D)] },
  "ekubo-yul-native": { specifiedToken: NATIVE, calculatedToken: B, hops: [hop(NATIVE, B)] },
};
for (const [file, r] of Object.entries(routes)) {
  const data = encodeRoute({
    ...r,
    specifiedAmount: 1000000000000000000n,
    calculatedAmountThreshold: 900000000000000000n, // 90% of input: 0.3% fee per hop cannot trip it
    recipient,
  });
  writeFileSync(`calldata/${file}.hex`, data);
  console.log(file, (data.length - 2) / 2, "bytes");
}
