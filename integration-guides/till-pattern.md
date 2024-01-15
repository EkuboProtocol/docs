---
description: Every interaction with Ekubo starts with a call to lock
---

# 💸 "Till" pattern

Ekubo is a singleton AMM that utilizes the "till" pattern. All pools and tokens are represented as state in a single contract. The till pattern was [publicly introduced](https://www.youtube.com/watch?v=xFp8RlRq0qU) at EthCC\[5] and is also described [here](https://github.com/OpenZeppelin/openzeppelin-contracts/issues/4361#issuecomment-1595095135). This is how Ekubo allows all token payments to be deferred until the end of your transaction.

{% hint style="info" %}
Even though the entrypoint for all methods is named `#lock`, Ekubo protocol supports reentrancy. Locks can be nested, meaning any contract you call can also interact with Ekubo.
{% endhint %}

Every interaction with Ekubo starts with `ICore#lock`. In order to interact with Ekubo, you must first implement the `ILocker` interface in your calling contract:

{% code title="icore.cairo" %}
```rust
#[starknet::interface]
trait ICore<TStorage> {
    fn lock(ref self: TStorage, data: Array<felt252>) -> Array<felt252>;
    fn swap(ref self: TStorage, pool_key: PoolKey, params: SwapParameters) -> Delta;
}

#[starknet::interface]
trait ILocker<TStorage> {
    fn locked(ref self: TStorage, id: u32, data: Array<felt252>) -> Array<felt252>;
}
```
{% endcode %}

You must then make all your swaps and position updates within the `#locked` callback. If you call any of these methods outside of a `locked` callback, the call will revert.

To know what you must do within the callback, encode your parameters into the data argument of the call to lock. The [shared\_locker.cairo](https://github.com/EkuboProtocol/abis/blob/main/src/shared\_locker.cairo) contains some useful functions for constructing the call to lock as well as consuming the locked callback data.
