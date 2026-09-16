import { encodeRoute } from "/home/sendmoodz/Work/ekubo/yul-router/sdk/src/index.ts";
const data = encodeRoute({
  specifiedToken: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  calculatedToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  specifiedAmount: 1000000000n,
  calculatedAmountThreshold: 990000000n,
  recipient: "0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496",
  hops: [
    {
      type: "core",
      poolKey: {
        token0: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        token1: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        config: "0x0000000000000000000000000000000000000000000053e2d6238da480000032",
      },
    },
  ],
});
console.log(data);
