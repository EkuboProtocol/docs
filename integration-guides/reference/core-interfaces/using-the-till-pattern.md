---
description: Every interaction with Ekubo starts with ICore#lock
---

# Using the "till" pattern

Ekubo is a singleton AMM that utilizes the "till" pattern. The till pattern was [publicly introduced](https://www.youtube.com/watch?v=xFp8RlRq0qU) at EthCC\[5] and is also described [here](https://github.com/OpenZeppelin/openzeppelin-contracts/issues/4361#issuecomment-1595095135). This is how Ekubo allows all your token payments to be deferred until the end of your transaction.

{% hint style="info" %}
Even though the entrypoint for all methods is called `ICore#lock`, Ekubo protocol supports re-entrancy. Locks can be nested, meaning any contract you call can also lock Ekubo. However, lock state is isolated so you only ever have to consider the actions you perform within your own lock.
{% endhint %}

Every interaction with Ekubo starts with `ICore#lock`. In order to interact with Ekubo, you must first implement the `ILocker` interface in your calling contract:

{% code title="interfaces/core.cairo" %}
```rust
#[starknet::interface]
trait ICore<TStorage> {
    // ... 

    fn lock(ref self: TStorage, data: Array<felt252>) -> Array<felt252>;

    fn swap(ref self: TStorage, pool_key: PoolKey, params: SwapParameters) -> Delta;
    
    // ...
}

#[starknet::interface]
trait ILocker<TStorage> {
    fn locked(ref self: TStorage, id: u32, data: Array<felt252>) -> Array<felt252>;
}
```
{% endcode %}

You must then perform your swaps and position updates within the callback. To know what you must do within the callback, encode your parameters such as the pools against which you'd like to swap, into the data argument. Below are some utility methods for writing contracts that make swaps or update positions.

```rust
use serde::Serde;
use starknet::{get_caller_address, call_contract_syscall, ContractAddress, SyscallResultTrait};
use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
use array::{ArrayTrait};
use option::{OptionTrait};

// Serialize some data for calling ICore#lock, and deserialize the result
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

// Called from within locked, to deserialize the input and do the appropriate caller check
fn consume_callback_data<TInput, impl TSerdeInput: Serde<TInput>>(
    core: ICoreDispatcher, callback_data: Array<felt252>
) -> TInput {
    assert(get_caller_address() == core.contract_address, 'CORE_ONLY');
    let mut span = callback_data.span();
    Serde::deserialize(ref span).expect('DESERIALIZE_INPUT_FAILED')
}

```
