---
description: >-
  Integrate Ekubo protocol to provide better prices to swappers or to perform
  arbitrage
---

# 🔄 Swapping

To swap on Ekubo, you must called `ICore#lock`. Ekubo's core contract will call back into your contract with the data you pass, via `IYourContract#locked`. In your lock callback, you must execute the swap, and pay the input, and withdraw the output in no particular order.

Note you can do multiple swaps in a single callback and you only have to pay any differences.&#x20;

### Example code

The below code locks the Ekubo core contract and calls swap, then pays for the input.

{% hint style="info" %}
Ekubo Protocol supports exact-output swaps, e.g. "buy 1 ETH, compute the input amount," by specifying a negative amount of the desired output token.
{% endhint %}

If you are making multiple trades against Ekubo, you will see better gas efficiency by utilizing only a single lock.

```rust
// Imports are implied
#[starknet::contract]
mod SwapExample {
  #[storage]
  struct Storage {
    core: ICoreDispatcher,
  }

  #[derive(Copy, Drop, Serde)]
  struct SwapData {
     pool_key: PoolKey,
     amount: i129,
     token: ContractAddress,
  }
  
  #[derive(Copy, Drop, Serde)]
  struct SwapResult {
     delta: Delta,
  }

  #[external(v0)]
  impl SwapExample of ISwapExample<ContractState> {
    fn swap(ref self: ContractState, swap_data: SwapData) -> SwapResult {
      // https://github.com/EkuboProtocol/abis/blob/main/src/components/shared_locker.cairo
      ekubo::components::shared_locker::call_core_with_callback(
        self.core.read(), @swap_data
      )
    }
  }

  #[external(v0)]
  impl Locker of ILocker<ContractState> {
    fn locked(ref self: ContractState, id: u32, data: Array<felt252>) -> Array<felt252> {
      let core = self.core.read();

      // Consume the callback data
      // https://github.com/EkuboProtocol/abis/blob/main/src/components/shared_locker.cairo
      let swap_data: SwapData = ekubo::components::shared_locker::consume_callback_data::<CallbackParameters>(core, data);
      
      // Do your swaps here!
      let delta = core.swap(pool_key, params);
      
      // Each swap generates a "delta", but does not trigger any token transfers.
      // Deltas are always from the perspective of the pool:
      //  - A negative delta indicates the pool owes you tokens.
      //  - A positive delta indicates you owe the pool tokens.
      // To take a negative delta out of core, do (assuming token0 for token1):
      core.withdraw(token, recipient, delta.amount0.mag);
      // To pay tokens you owe, do (assuming payment is for token1):
      IERC20Dispatcher {
        contract_address: token
      }.approve(ekubo, delta.amount1.mag.into());
      // ICoreDispatcher#pay will trigger a token#transferFrom(this, core) for the entire approved amount
      core.pay(token);
      
      // Serialize our output type into the return data
      let swap_result = SwapResult { delta };
      let mut arr: Array<felt252> = ArrayTrait::new();
      Serde::serialize(@swap_result, ref arr);
      arr
    }
  }
}
```

{% hint style="info" %}
Instead of withdrawing a delta, you can also save the delta for later using `#save`. Later, you can load it to pay for swaps using `#load`. This completely avoids token transfers, which can protect you from undesirable token behavior such as fee-on-transfer. Note you must give a user another different token to represent the saved balance.
{% endhint %}

### Note on Extensions

[Extensions](extensions/) can modify pool state before you get to swap against it. Some extensions will update positions just-in-time before the swap, and others will front-run a swap with their own.

There are 2 ways to integrate extensions as a swapper:

* read the code for the extension and support it by off-chain simulation
* use a quoter contract to simulate swaps across pools, which always includes extension behavior

With the latter approach, you will always be susceptible to per-block changes in behavior of the extension, however this is no different from exposure to other front-runners. You should always check the amounts received from a swap are better than some slippage-adjusted amount to protect the user from misbehaving extensions, in the exact same way you would protect against front running.
