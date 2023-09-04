---
description: >-
  Integrate Ekubo protocol to provide better prices to swappers or to perform
  arbitrage
---

# Swapping

## Summary

Ekubo, Inc. does not provide any code for swapping against Ekubo pools. We believe users should get the best price, and would not build an interface that ever offers them anything less by aggregating _only_ Ekubo liquidity.

We rely on an ecosystem of aggregators to provide the best routing for swapping against Ekubo pools as well as other AMMs in the ecosystem. Below is a sample of some code that could be used to swap against the Ekubo pools.

### Example code

The below code locks the Ekubo core contract and calls swap, then pays for the input.

{% hint style="info" %}
Ekubo Protocol supports exact-output swaps, e.g. "buy 1 ETH, compute the input amount," by specifying a negative amount of the desired output token.
{% endhint %}

If you are making multiple trades against Ekubo, for example , you will see much better gas efficiency by utilizing only a single lock.

```rust
// Imports are implied
#[starknet::contract]
mod AggregatorExample {
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
  impl AggregatorExampleImpl of IAggregatorExample<ContractState> {
    fn aggregator_swap(ref self: ContractState, swap_data: SwapData) -> SwapResult {
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
      // To take a negative delta out of core, do (assuming token0 for token1):
      ICoreDispatcher { contract_address: ekubo }.withdraw(token, recipient, delta.amount0.mag);
      // To pay tokens you owe, do (assuming token1):
      IERC20Dispatcher {
        contract_address: token
      }.transfer(ekubo, delta.mag.into());
      ICoreDispatcher { contract_address: ekubo }.deposit(token);
      
      let mut arr: Array<felt252> = ArrayTrait::new();
      Serde::<SwapResult>::serialize(@result, ref arr);
      arr
    }
  }
}
```

{% hint style="info" %}
Instead of withdrawing a delta, you can also save the delta for later using `#save`. Later, you can load it to pay for swaps using `#load`. This completely avoids token transfers, which can protect you from undesirable token behavior such as fee-on-transfer. Note you must give a user another different token to represent the saved balance.
{% endhint %}

### Note on Extensions

[Extensions](../extensions/) can modify pool state before you get to swap against it. Some extensions will update positions just-in-time before the swap, and others will front-run a swap with their own.

There are 2 ways to integrate extensions as a swapper:

* read the code for the extension and support it by off-chain simulation
* use a quoter contract to simulate swaps across pools, which always includes extension behavior

With the latter approach, you will always be susceptible to per-block changes in behavior of the extension, however this is no different from exposure to other front-runners. You should always check the amounts received from a swap are better than some slippage-adjusted amount to protect the user from misbehaving extensions, in the exact same way you would protect against front running.
