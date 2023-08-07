---
description: Customize pool behavior by writing extension contracts
---

# Extensions

### Summary

Extensions allow you to insert custom logic at certain pool lifecycle events. This enables third party developers to leverage the efficient and secure core AMM protocol of Ekubo, including concentrated liquidity, without implementing any of the math!&#x20;

But why should you build your custom pool as an extension? Extensions allow third-party developers to more easily tap into existing integrations, e.g. with aggregators and arbitrageurs. You can build pretty much any curve just by overlapping several `x*y=k` positions, which means Ekubo's core components can be used for many different AMM use cases. In the extreme case, you can use Ekubo as an order book with its extremely small ticks.

Because an extension can re-enter the core Ekubo contract to perform its own actions within these lifecycle events, this simple interface allows for a huge amount of customization of pool behavior. For example, you could front-run a swap by adding your own liquidity, providing price improvement. Or, you could read the pool price at the beginning of the block to provide an oracle.

Extensions are specified as part of the pool key. In other words, the specified extension is an immutable configuration of a pool. When the pool is initialized, an extension is always called before the initialization, and at this point the extension can specify at what points it should be called in the future. The set of "call points" never changes for the pool, so you should specify all the places you might need to respond to pool actions.

Because extensions can have their own state like any other contract, you can use this state to determine how to react to certain lifecycle events. For example, limit orders can be created by:

* Add functions that allow users to create limit orders via your extension
* Immediately add liquidity to the pool for new limit orders
* After swaps, remove any limit orders from the pool that were fully executed

{% hint style="info" %}
Because extensions are immutable for a pool, you must either make them upgradeable, or focus on making them so simple they do not need to be upgraded.
{% endhint %}

### Example

```rust
use starknet::{ContractAddress, ClassHash};
use ekubo::types::pool_price::{PoolPrice};
use ekubo::types::position::{Position};
use ekubo::types::fees_per_liquidity::{FeesPerLiquidity};
use ekubo::types::tick::{Tick};
use ekubo::types::keys::{PositionKey, PoolKey};
use ekubo::types::i129::{i129};
use ekubo::types::bounds::{Bounds};
use ekubo::types::delta::{Delta};
use ekubo::types::call_points::{CallPoints};

// Represents a signed integer in a 129 bit container, where the sign is 1 bit and the other 128 bits are magnitude
// Note the sign can be true while mag is 0, meaning 1 value is wasted 
// (i.e. sign == true && mag == 0 is redundant with sign == false && mag == 0)
#[derive(Copy, Drop, Serde)]
struct i129 {
    mag: u128,
    sign: bool,
}

// Passed as an argument to update a position. The owner of the position is implicitly the locker.
// bounds is the lower and upper price range of the position, expressed in terms of log base sqrt 1.000001 of token1/token0.
// liquidity_delta is how the position's liquidity should be updated.
#[derive(Copy, Drop, Serde)]
struct UpdatePositionParameters {
    salt: u64,
    bounds: Bounds,
    liquidity_delta: i129,
}

// The amount is the amount of token0 or token1 to swap, depending on is_token1. A negative amount implies an exact-output swap.
// is_token1 Indicates whether the amount is in terms of token0 or token1.
// sqrt_ratio_limit is a limit on how far the price can move as part of the swap. Note this must always be specified, and must be between the maximum and minimum sqrt ratio.
// skip_ahead is an optimization parameter for large swaps across many uninitialized ticks to reduce the number of swap iterations that must be performed
#[derive(Copy, Drop, Serde)]
struct SwapParameters {
    amount: i129,
    is_token1: bool,
    sqrt_ratio_limit: u256,
    skip_ahead: u32,
}

// Details about a liquidity position. Note the position may not exist, i.e. a position may be returned that has never had non-zero liquidity.
// Note you should not rely on fees per liquidity inside to be consistent across calls, since it also is used to track accumulated fees over time
#[derive(Copy, Drop, Serde)]
struct GetPositionWithFeesResult {
    position: Position,
    fees0: u128,
    fees1: u128,
    // the current value of fees per liquidity inside is required to compute the fees, so it is also returned to save computation
    fees_per_liquidity_inside_current: FeesPerLiquidity,
}

// The current state of the queried locker
#[derive(Copy, Drop, Serde)]
struct LockerState {
    address: ContractAddress,
    nonzero_delta_count: u32
}

// An extension is an optional contract that can be specified as part of a pool key to modify pool behavior
#[starknet::interface]
trait IExtension<TStorage> {
    // Called before a pool is initialized, and returns where the extension should be called in future operations
    fn before_initialize_pool(
        ref self: TStorage, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129
    ) -> CallPoints;
    // Called after a pool is initialized
    fn after_initialize_pool(
        ref self: TStorage, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129
    );

    // Called before a swap happens
    fn before_swap(
        ref self: TStorage, caller: ContractAddress, pool_key: PoolKey, params: SwapParameters
    );
    // Called after a swap happens with the result of the swap
    fn after_swap(
        ref self: TStorage,
        caller: ContractAddress,
        pool_key: PoolKey,
        params: SwapParameters,
        delta: Delta
    );

    // Called before an update to a position
    fn before_update_position(
        ref self: TStorage,
        caller: ContractAddress,
        pool_key: PoolKey,
        params: UpdatePositionParameters
    );
    // Called after the position is updated with the result of the update
    fn after_update_position(
        ref self: TStorage,
        caller: ContractAddress,
        pool_key: PoolKey,
        params: UpdatePositionParameters,
        delta: Delta
    );
}
```
