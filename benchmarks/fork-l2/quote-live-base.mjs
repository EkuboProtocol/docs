import {
  encodeRoute,
  encodeQuoteCalldata,
} from "/home/sendmoodz/Work/ekubo/yul-router/sdk/src/index.ts";
// live Base pool from the Ekubo API poolKeys listing: native ETH / USDC, fee 0x20c49ba5e353f7 (0.05%), spacing 1000
const route = encodeRoute({
  specifiedToken: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  calculatedToken: "0x0000000000000000000000000000000000000000",
  specifiedAmount: 1_000_000n,
  calculatedAmountThreshold: false,
  recipient: "0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496",
  hops: [
    {
      type: "core",
      poolKey: {
        token0: "0x0000000000000000000000000000000000000000",
        token1: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        config:
          "0x00000000000000000000000000000000000000000020c49ba5e353f7800003e8",
      },
    },
  ],
});
console.log(encodeQuoteCalldata(route));
