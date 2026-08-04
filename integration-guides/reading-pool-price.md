---
description: How to interpret pool data from the on-chain methods
---

# Reading pool price

How to read a pool's current price on-chain and convert it to a human-readable number. For how prices are encoded (fixed point on Starknet, the compact `SqrtRatio` float type on EVM), see [Price representation](../reference/price-representation.md).

## EVM (V3)

The simplest way to read a pool price on EVM chains is the `CoreDataFetcher` lens contract (deployed at the same address on every chain — see [EVM Contracts (V3)](../reference/contracts/evm-v3.md)):

```solidity
// returns the sqrt ratio expanded to 64.128 fixed point, plus the current tick
(uint256 sqrtRatioFixed, int32 tick) = coreDataFetcher.poolPrice(poolKey);
```

The returned value is a 64.128 fixed-point number — identical semantics to Starknet's `sqrt_ratio` below, so the conversion to a human-readable price is the same: divide by `2**128`, square, and adjust for token decimals. (If you read Core's packed pool state directly instead, the price is a 96-bit `SqrtRatio`; call `toFixed()` on it or see [Price representation](../reference/price-representation.md) for the bit layout.)

Note that on EVM, native ETH is represented as `address(0)`, so ETH is always `token0` of any pool it is in.

## Starknet

Let's say you wanted to determine the human-readable price of the ETH-USDC pool on Starknet mainnet.

These two tokens are:

* **ETH**: `0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7` ([Voyager](https://voyager.online/contract/0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7))
* **USDC**: `0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8` ([Voyager](https://voyager.online/contract/0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8))

First, let's determine which token is `token0` and which token is `token1`. We can do this by comparing the integer values of the addresses. In this case, `0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 > 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7`, so USDC is `token1` and ETH is `token0`.

Next, we need to decide which pool to read. Let's use the pool with the 0.05% fee and the 0.1% tick spacing, since it's the most popular ETH/USDC pool. The easiest way to get the fee and tick spacing parameters is to [read the URL](https://app.ekubo.org/positions/new?baseCurrency=ETH\&quoteCurrency=USDC\&fee=170141183460469235273462165868118016\&tickSpacing=1000\&step=1\&tickLower=-20104000\&tickUpper=-20064000\&initialTick=-20083671) from the website when you add liquidity to this pool:

```
https://app.ekubo.org/positions/new?baseCurrency=ETH&quoteCurrency=USDC&fee=170141183460469235273462165868118016&tickSpacing=1000
```

The second easiest way is to compute the value. Fee is a 0.128 fixed point number, so to compute the fee, we can do [`floor(0.05% * 2**128)`](https://www.wolframalpha.com/input?i=floor%280.05%25*2**128%29). The result is `170141183460469235273462165868118016`.  The tick spacing of `0.01%` is represented as an exponent of `1.000001`, so it can be computed as [`log base 1.000001 of 1.001`](https://www.wolframalpha.com/input?i=log+base+1.000001+of+1.001), which is roughly equal to `1000`. The extension is `0` because it is not used for this pool.

Input the values into the [Core](../reference/contracts/evm-v2.md) contract on Voyager to read the pool price. If you're following along, you'll get a value that looks like this:

```json
{
    "sqrt_ratio": "0x029895c9cbfca44f2c46e6e9b5459b",
    "tick": {
        "mag": "0x0135566d",
        "sign": "0x01"
    },
    "call_points": {
        "after_initialize_pool": "0x00",
        "before_swap": "0x00",
        "after_swap": "0x00",
        "before_update_position": "0x00",
        "after_update_position": "0x00"
    }
}
```

Let's compute the price from this result. The value `sqrt_ratio` is a `64.128` fixed point number. To convert it to a price, first divide it by `2**128`, then square it to get the price. Since USDC is `token1`, this value is the price of the pool in USDC/ETH. `(0x029895c9cbfca44f2c46e6e9b5459b / 2**128)**2 == 1.56914... ×10^-9`. To adjust for display, we have to account for the decimal difference between the USDC and ETH tokens. Because USDC has 6 decimals and ETH has 18 decimals, we need to scale it up by `10**(18-6)` to be human readable. `1.56914e-9 * 1e12 == 1.56914e3 == 1569.14 USDC/ETH`.

