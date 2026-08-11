---
description: Take advantage of liquidity in Ekubo pools to provide better pricing for users
title: "Aggregators"
---

:::note
The code samples on this page are written in Cairo for the Starknet deployment. The same lock/callback flow applies on EVM chains — see [Swapping](/integration-guides/swapping/) and the [EVM contracts repository](https://github.com/EkuboProtocol/evm-contracts) for Solidity equivalents.
:::

## Reference implementations

Several production aggregators publish their Ekubo V3 integrations. They all need the same three capabilities — discover pools, keep pool state current, and turn a route into executable calldata — but divide the work differently.

| Implementation                                                                                      | State acquisition                                                         | Quoting                                                                   | Execution                                                                     |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [Tycho](https://github.com/propeller-heads/tycho)                                                   | Substreams produce protocol components and per-block state deltas         | Rust simulators reconstruct each supported pool type                      | A Rust encoder targets a dedicated Solidity executor                          |
| [ParaSwap](https://github.com/VeloraDEX/paraswap-dex-lib/tree/master/src/dex/ekubo-v3)              | A subgraph bootstrap transitions to event-driven pool state               | TypeScript pool models quote exact-input and exact-output amounts locally | The adapter encodes a call to Ekubo's router                                  |
| [KyberSwap](https://github.com/KyberNetwork/kyberswap-dex-lib/tree/main/pkg/liquidity-source/ekubo) | Indexed pool discovery plus log application, with an RPC refresh fallback | Go pool simulators quote and update cloned route state locally            | The simulator returns the pool key and swap metadata to Kyber's routing layer |

### Tycho

Tycho separates the integration into independent ingestion, simulation, and execution layers:

- The [`ethereum-ekubo-v3` Substreams package](https://github.com/propeller-heads/tycho/tree/main/protocols/substreams/ethereum-ekubo-v3) maps initialization and swap-related events into protocol components, balances, active ticks, liquidity, and extension-specific rate changes.
- The [`ekubo_v3` simulation module](https://github.com/propeller-heads/tycho/tree/main/crates/tycho-simulation/src/evm/protocol/ekubo_v3) decodes those components and simulates concentrated, full-range, stableswap, oracle, TWAMM, MEV-capture, and boosted-fees pools. Its default filter excludes pools whose extensions cannot be simulated safely; signed-exclusive swaps have an explicit opt-in path because they require off-chain user data.
- The [`EkuboV3SwapEncoder`](https://github.com/propeller-heads/tycho/blob/main/crates/tycho-execution/src/encoding/evm/swap_encoder/ekubo_v3.rs) converts a selected pool and amount into compact calldata for [`EkuboV3Executor.sol`](https://github.com/propeller-heads/tycho/blob/main/crates/tycho-execution/contracts/src/executors/EkuboV3Executor.sol), including the optional signed-swap payload.

This architecture is useful when an indexer serves many routing clients: normalized state changes can be streamed once, while each client maintains a local simulator and the execution service remains a separate concern.

### ParaSwap

ParaSwap keeps the integration together in its TypeScript DEX adapter:

- [`EkuboV3PoolManager`](https://github.com/VeloraDEX/paraswap-dex-lib/blob/master/src/dex/ekubo-v3/ekubo-v3-pool-manager.ts) pages through pool initializations from the subgraph, verifies the handoff against the canonical chain, subscribes before that handoff to avoid a gap, and then forwards Core and extension logs to the relevant in-memory pool.
- The [`pools` directory](https://github.com/VeloraDEX/paraswap-dex-lib/tree/master/src/dex/ekubo-v3/pools) implements pool-specific state transitions and math. The adapter's [`getPricesVolume`](https://github.com/VeloraDEX/paraswap-dex-lib/blob/master/src/dex/ekubo-v3/ekubo-v3.ts) quotes each requested size locally, rejects pools that cannot consume the complete amount, and returns gas estimates and `skipAhead` hints to the route search.
- Once a route is chosen, `getDexParam` in the same adapter encodes `swapAllowPartialFill` against Ekubo's router with the pool key, signed amount, direction, skip-ahead value, and recipient.

The notable pattern is the guarded transition from indexed history to live logs. If you bootstrap from a subgraph and then follow RPC events, you need an equivalent continuity and reorg strategy or your local state can silently miss a block.

### KyberSwap

KyberSwap uses a Go liquidity-source package with explicit discovery, tracking, and simulation stages:

- [`pools_list_updater.go`](https://github.com/KyberNetwork/kyberswap-dex-lib/blob/main/pkg/liquidity-source/ekubo/v3/pools_list_updater.go) pages through indexed pool initializations, recognizes supported pool and extension configurations, and fetches the initial on-chain state in batches.
- [`pool_tracker.go`](https://github.com/KyberNetwork/kyberswap-dex-lib/blob/main/pkg/liquidity-source/ekubo/v3/pool_tracker.go) applies ordered Core, TWAMM, boosted-fees, and ve33 logs to the stored pool. A removed log, missing log batch, or failed state transition triggers a full refresh through the data fetchers.
- [`pool_simulator.go`](https://github.com/KyberNetwork/kyberswap-dex-lib/blob/main/pkg/liquidity-source/ekubo/v3/pool_simulator.go) supports exact-input and exact-output quotes, reports consumed amount, fees and gas, clones mutable swap state for route exploration, and updates balances after a simulated hop.

This design makes recovery behavior especially explicit: event application is the fast path, while authoritative on-chain reads are the correctness fallback.

## Summary

Ekubo is a singleton AMM that utilizes the "till" pattern. The till pattern was publicly introduced at EthCC\[5] and is also described [here](https://github.com/OpenZeppelin/openzeppelin-contracts/issues/4361#issuecomment-1595095135).

Every interaction with Ekubo starts with `ICore#lock`. In order to interact with Ekubo, you must first implement the `ILocker` interface in your calling contract:

```rust
#[starknet::interface]
trait ICore<TStorage> {
    // ...

    // Main entrypoint for any actions, which must be called before any other pool functions can be called.
    // Other functions must be called within the callback to lock. The ILocker#locked function is called with the input data,
    // and the returned array is passed through to the caller.
    fn lock(ref self: TStorage, data: Array<felt252>) -> Array<felt252>;

    // Make a swap against a pool.
    // You must call this within a lock callback.
    fn swap(ref self: TStorage, pool_key: PoolKey, params: SwapParameters) -> Delta;

    // ...
}

// This interface must be implemented by any contract that intends to call ICore#lock
#[starknet::interface]
trait ILocker<TStorage> {
    // This function is called on the caller of lock, i.e. a callback
    // The input is the data passed to ICore#lock, the output is passed back through as the return value of #lock
    fn locked(ref self: TStorage, id: u32, data: Array<felt252>) -> Array<felt252>;
}
```

You must then perform your swaps within the callback. To know which swaps you need to do, encode your parameters, such as the pools against which you'd like to swap, into the data argument

An example locker might look like this:

```rust
// ILocksCoreExample interface and imports are implied here

#[starknet::contract]
mod Example {
  #[storage]
  struct Storage {
    ekubo: ContractAddress,
  }

  #[derive(Copy, Drop, Serde)]
  struct SwapData {
     // the list of pools that you'd like to swap against, etc.
  }

  #[derive(Copy, Drop, Serde)]
  struct SwapResult {
     // the result of the swap
  }

  #[external(v0)]
  impl LocksCoreExample of ILocksCoreExample<ContractState> {
    fn swap(ref self: ContractState, swap_data: SwapData) -> SwapResult {
      let mut arr: Array<felt252> = ArrayTrait::new();
      Serde::<SwapData>::serialize(@swap_data, ref arr);

      let result = ICoreDispatcher { contract_address: self.ekubo.read() }.lock(arr);

      let mut result_data = result.span();
      let mut result: SwapResult = Serde::<SwapResult>::deserialize(
          ref result_data
      )
          .expect('DESERIALIZE_RESULT_FAILED');

      result
    }

    fn locked(ref self: ContractState, id: u32, data: Array<felt252>) -> Array<felt252> {
      let caller = get_caller_address();
      let ekubo = self.ekubo.read();
      // Only allow Ekubo's core contract to call this method.
      assert(caller == ekubo, 'UNAUTHORIZED_CALLBACK');

      let mut swap_data_span = data.span();
      let mut swap_data: SwapData = Serde::<SwapData>::deserialize(ref swap_data_span)
          .expect('DESERIALIZE_FAILED');

      // Do your swaps here! e.g.:
      // let delta = ICoreDispatcher { contract_address: ekubo }.swap(pool_key, params);

      // Each swap generates a "delta", but does not trigger any token transfers.
      // A negative delta indicates you are owed tokens. A positive delta indicates core owes you tokens.
      // To take a negative delta out of core, do (assuming token0):
      // ICoreDispatcher { contract_address: ekubo }.withdraw(token, recipient, delta.amount0.mag);
      // To pay tokens you owe, do (assuming token1):
      // IERC20Dispatcher {
      //   contract_address: token
      // }.transfer(ekubo, u256 { low: delta.mag, high: 0 });
      // assert(
      //   ICoreDispatcher { contract_address: ekubo }.deposit(token) == delta.amount1.mag,
      //   'DEPOSIT_FAILED'
      // );


      let mut arr: Array<felt252> = ArrayTrait::new();
      Serde::<SwapResult>::serialize(@result, ref arr);
      arr
    }
  }
}
```

:::note
Instead of withdrawing a delta, you can also save it for use later using `#save` or load it using `#load`.
:::

## Locker utility method

You may wish to use this shared code to call core with some calldata and automagically deserialize the result:

```rust
use serde::Serde;
use starknet::{call_contract_syscall, ContractAddress, SyscallResultTrait};
use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
use array::{ArrayTrait};
use option::{OptionTrait};

fn call_core_with_callback<
    TInput, impl TSerdeInput: Serde<TInput>, TOutput, impl TSerdeOutput: Serde<TOutput>,
>(
    core: ICoreDispatcher, input: @TInput
) -> TOutput {
    let mut input_data: Array<felt252> = ArrayTrait::new();
    Serde::serialize(input, ref input_data);

    let mut output_span = core.lock(input_data).span();

    Serde::deserialize(ref output_span).expect('DESERIALIZE_RESULT_FAILED')
}
```

## Note on extensions

Extensions are third-party code that can change the result of swapping against a pool, usually by updating liquidity positions before the swap — though an extension may also front-run a swap with one of its own.

There are two ways to handle extensions:

- read the code for the extension and support it by off-chain simulation
- use the quoter to simulate swaps across pools, which always includes extension behavior

With the latter approach you remain exposed to per-block changes in an extension's behavior, but this is no different from exposure to any other front-runner. Always check the resulting output amount against an expected slippage tolerance, protecting users from a misbehaving extension exactly as you would from front-running.
