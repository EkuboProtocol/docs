---
description: Take advantage of liquidity in Ekubo pools to provide better pricing for users
---

# Aggregators

{% hint style="info" %}
The code samples on this page are written in Cairo for the Starknet deployment. The same lock/callback flow applies on EVM chains — see [Swapping](swapping.md) and the [EVM contracts repository](https://github.com/EkuboProtocol/evm-contracts) for Solidity equivalents.
{% endhint %}

### Summary

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

{% hint style="info" %}
Instead of withdrawing a delta, you can also save it for use later using `#save` or load it using `#load`.
{% endhint %}

### Locker utility method

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

### Note on extensions

Extensions are third party code that can change the result of swapping against a pool, mainly by updating liquidity positions before the swap, but it's also possible that an extension front-runs a swap with their own.

Thus, there are 2 ways to integrate extensions:

* read the code for the extension and support it by off-chain simulation
* use the quoter to simulate swaps across pools, which always includes extension behavior

With the latter approach, you will always be susceptible to per-block changes in behavior of the extension, however this is no different from exposure to other front runners. You should always check the resulting output amount against some expected slippage tolerance to protect the user from misbehaving extensions, in the same way you would protect against front running.
