---
description: The external interfaces for interacting with Ekubo Protocol
---

# Core Interfaces

<details>

<summary>core.cairo</summary>

{% code lineNumbers="true" fullWidth="true" %}
```rust
use starknet::{ContractAddress, ClassHash};

// Uniquely identifies a pool
// token0 is the token with the smaller address (sorted by integer value)
// token1 is the token with the larger address (sorted by integer value)
// fee is specified as a 0.128 number, so 1% == 2**128 / 100
// tick_spacing is the minimum spacing between initialized ticks, i.e. ticks that positions may use
// extension is the address of a contract that implements additional functionality for the pool
#[derive(Copy, Drop, Serde)]
struct PoolKey {
    token0: ContractAddress,
    token1: ContractAddress,
    fee: u128,
    tick_spacing: u128,
    extension: ContractAddress,
}

// Tick bounds for a position
#[derive(Copy, Drop, Serde)]
struct Bounds {
    lower: i129,
    upper: i129
}

// From the perspective of the core contract, this represents the change in balances.
// For example, swapping 100 token0 for 150 token1 would result in a Delta of { amount0: 100, amount1: -150 }
// Note in case the price limit is reached, the amount0 or amount1_delta may be less than the amount specified in the swap parameters.
#[derive(Copy, Drop, Serde)]
struct Delta {
    amount0: i129,
    amount1: i129,
}

// salt is a random number specified by the owner to allow a single address to control many positions with the same pool and bounds
// owner is the immutable address of the position
// bounds is the price range where the liquidity of the position is active
#[derive(Copy, Drop, Serde)]
struct PositionKey {
    salt: u64,
    owner: ContractAddress,
    bounds: Bounds,
}

#[derive(Copy, Drop, Serde)]
struct FeesPerLiquidity {
    value0: felt252,
    value1: felt252,
}

#[derive(Copy, Drop, Serde)]
struct Position {
    // the amount of liquidity owned by the position
    liquidity: u128,
    // the fee per liquidity inside the tick range of the position, the last time it was computed
    fees_per_liquidity_inside_last: FeesPerLiquidity,
}

// Represents a signed integer in a 129 bit container, where the sign is 1 bit and the other 128 bits are magnitude
// Note the sign can be true while mag is 0, meaning 1 value is wasted 
// (i.e. sign == true && mag == 0 is redundant with sign == false && mag == 0)
#[derive(Copy, Drop, Serde)]
struct i129 {
    mag: u128,
    sign: bool,
}

// The points at which an extension should be called
#[derive(Copy, Drop, Serde)]
struct CallPoints {
    after_initialize_pool: bool,
    before_swap: bool,
    after_swap: bool,
    before_update_position: bool,
    after_update_position: bool,
}

#[derive(Copy, Drop, Serde)]
struct PoolPrice {
    // the current ratio, up to 192 bits
    sqrt_ratio: u256,
    // the current tick, up to 32 bits
    tick: i129,
    // the places where specified extension should be called, 5 bits
    call_points: CallPoints,
}

// This interface must be implemented by any contract that intends to call ICore#lock
#[starknet::interface]
trait ILocker<TStorage> {
    // This function is called on the caller of lock, i.e. a callback
    // The input is the data passed to ICore#lock, the output is passed back through as the return value of #lock
    fn locked(ref self: TStorage, id: u32, data: Array<felt252>) -> Array<felt252>;
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

#[starknet::interface]
trait ICore<TStorage> {
    // Sets the contract to withdrawals only mode, thus preventing any new capital being sent to the contract
    fn set_withdrawal_only_mode(ref self: TStorage);

    // Returns whether the contract is in withdrawal only mode
    fn get_withdrawal_only_mode(self: @TStorage) -> bool;

    // Get the amount of withdrawal fees collected for the protocol
    fn get_protocol_fees_collected(self: @TStorage, token: ContractAddress) -> u128;

    // Get the state of the locker with the given ID
    fn get_locker_state(self: @TStorage, id: u32) -> LockerState;

    // Get the price of the pool
    fn get_pool_price(self: @TStorage, pool_key: PoolKey) -> PoolPrice;

    // Get the liquidity of the pool
    fn get_pool_liquidity(self: @TStorage, pool_key: PoolKey) -> u128;

    // Get the current all-time fees per liquidity for the pool
    fn get_pool_fees_per_liquidity(self: @TStorage, pool_key: PoolKey) -> FeesPerLiquidity;

    // Get the fees per liquidity inside a given tick range for a pool
    fn get_pool_fees_per_liquidity_inside(
        self: @TStorage, pool_key: PoolKey, bounds: Bounds
    ) -> FeesPerLiquidity;

    // Get the liquidity delta for the tick of the given pool
    fn get_pool_tick_liquidity_delta(self: @TStorage, pool_key: PoolKey, index: i129) -> i129;

    // Get the net liquidity referencing a tick for the given pool
    fn get_pool_tick_liquidity_net(self: @TStorage, pool_key: PoolKey, index: i129) -> u128;

    // Get the fees on the other side of the tick from the current tick
    fn get_pool_tick_fees_outside(
        self: @TStorage, pool_key: PoolKey, index: i129
    ) -> FeesPerLiquidity;

    // Get the state of a given position for the given pool
    fn get_position(self: @TStorage, pool_key: PoolKey, position_key: PositionKey) -> Position;

    // Get the state of a given position for the given pool including the calculated fees
    fn get_position_with_fees(
        self: @TStorage, pool_key: PoolKey, position_key: PositionKey
    ) -> GetPositionWithFeesResult;

    // Get the last recorded balance of a token for core, used by core for computing payment amounts
    fn get_reserves(self: @TStorage, token: ContractAddress) -> u256;

    // Get the balance that is saved in core for a given account for use in a future lock (i.e. methods #save and #load)
    fn get_saved_balance(
        self: @TStorage, owner: ContractAddress, token: ContractAddress, cache_key: u64
    ) -> u128;

    // Return the next initialized tick from the given tick, i.e. the initialized tick that is greater than the given `from` tick
    fn next_initialized_tick(
        self: @TStorage, pool_key: PoolKey, from: i129, skip_ahead: u32
    ) -> (i129, bool);

    // Return the previous initialized tick from the given tick, i.e. the initialized tick that is less than or equal to the given `from` tick
    // Note this can also be used to check if the tick is initialized
    fn prev_initialized_tick(
        self: @TStorage, pool_key: PoolKey, from: i129, skip_ahead: u32
    ) -> (i129, bool);

    // Withdraws any fees collected by the contract (only the owner can call this function)
    fn withdraw_protocol_fees(
        ref self: TStorage, recipient: ContractAddress, token: ContractAddress, amount: u128
    );

    // Locks the core contract, allowing other functions to be called that require locking.
    // The lock callback is called with the input data, and the returned array is passed through to the caller.
    fn lock(ref self: TStorage, data: Array<felt252>) -> Array<felt252>;

    // Withdraws a given token from core. This is used to withdraw the output of swaps or burnt liquidity, and also for flash loans.
    // Must be called within a ILocker#locked
    fn withdraw(
        ref self: TStorage, token_address: ContractAddress, recipient: ContractAddress, amount: u128
    );

    // Save a given token balance in core for a given account for use in a future lock. It can be recalled by calling load.
    // Must be called within a ILocker#locked by the locker
    // Returns the next saved balance for that token, cache_key, recipient tuple
    fn save(
        ref self: TStorage,
        token_address: ContractAddress,
        cache_key: u64,
        recipient: ContractAddress,
        amount: u128
    ) -> u128;

    // Deposit a given token into core. This is how payments are made. First send the token to core, and then call deposit to account the delta.
    // Must be called within a ILocker#locked
    fn deposit(ref self: TStorage, token_address: ContractAddress) -> u128;

    // Recall a balance previously saved via #save
    // Must be called within a ILocker#locked, but it can be called by addresses other than the locker
    // Returns the next saved balance for that token, cache_key, spender tuple
    fn load(
        ref self: TStorage, token_address: ContractAddress, cache_key: u64, amount: u128
    ) -> u128;


    // Initialize a pool. This can happen outside of a lock callback because it does not require any tokens to be spent.
    fn initialize_pool(ref self: TStorage, pool_key: PoolKey, initial_tick: i129) -> u256;

    // Initialize a pool if it's not already initialized. Useful as part of a batch of other operations.
    fn maybe_initialize_pool(
        ref self: TStorage, pool_key: PoolKey, initial_tick: i129
    ) -> Option<u256>;

    // Update a liquidity position in a pool. The owner of the position is always the locker.
    // Must be called within a ILocker#locked. Note also that a position cannot be burned to 0 unless all fees have been collected
    fn update_position(
        ref self: TStorage, pool_key: PoolKey, params: UpdatePositionParameters
    ) -> Delta;

    // Collect the fees owed on a position
    fn collect_fees(ref self: TStorage, pool_key: PoolKey, salt: u64, bounds: Bounds) -> Delta;

    // Make a swap against a pool.
    // You must call this within a lock callback.
    fn swap(ref self: TStorage, pool_key: PoolKey, params: SwapParameters) -> Delta;

    // Accumulates tokens to fees of a pool. 
    // This is useful for extensions, e.g. extensions that do arbitrage based on external data and want to return profits to in-range LPs
    // You must call this within a lock callback.
    fn accumulate_as_fees(
        ref self: TStorage, pool_key: PoolKey, amount0: u128, amount1: u128
    ) -> Delta;
}

```
{% endcode %}

</details>

<details>

<summary>core-abi.json</summary>

```json
[
  {
    "type": "impl",
    "name": "Upgradeable",
    "interface_name": "ekubo::interfaces::upgradeable::IUpgradeable"
  },
  {
    "type": "interface",
    "name": "ekubo::interfaces::upgradeable::IUpgradeable",
    "items": [
      {
        "type": "function",
        "name": "replace_class_hash",
        "inputs": [
          {
            "name": "class_hash",
            "type": "core::starknet::class_hash::ClassHash"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      }
    ]
  },
  {
    "type": "impl",
    "name": "Core",
    "interface_name": "ekubo::interfaces::core::ICore"
  },
  {
    "type": "enum",
    "name": "core::bool",
    "variants": [
      {
        "name": "False",
        "type": "()"
      },
      {
        "name": "True",
        "type": "()"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::interfaces::core::LockerState",
    "members": [
      {
        "name": "address",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "nonzero_delta_count",
        "type": "core::integer::u32"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::keys::PoolKey",
    "members": [
      {
        "name": "token0",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "token1",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "fee",
        "type": "core::integer::u128"
      },
      {
        "name": "tick_spacing",
        "type": "core::integer::u128"
      },
      {
        "name": "extension",
        "type": "core::starknet::contract_address::ContractAddress"
      }
    ]
  },
  {
    "type": "struct",
    "name": "core::integer::u256",
    "members": [
      {
        "name": "low",
        "type": "core::integer::u128"
      },
      {
        "name": "high",
        "type": "core::integer::u128"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::i129::i129",
    "members": [
      {
        "name": "mag",
        "type": "core::integer::u128"
      },
      {
        "name": "sign",
        "type": "core::bool"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::call_points::CallPoints",
    "members": [
      {
        "name": "after_initialize_pool",
        "type": "core::bool"
      },
      {
        "name": "before_swap",
        "type": "core::bool"
      },
      {
        "name": "after_swap",
        "type": "core::bool"
      },
      {
        "name": "before_update_position",
        "type": "core::bool"
      },
      {
        "name": "after_update_position",
        "type": "core::bool"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::pool_price::PoolPrice",
    "members": [
      {
        "name": "sqrt_ratio",
        "type": "core::integer::u256"
      },
      {
        "name": "tick",
        "type": "ekubo::types::i129::i129"
      },
      {
        "name": "call_points",
        "type": "ekubo::types::call_points::CallPoints"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::fees_per_liquidity::FeesPerLiquidity",
    "members": [
      {
        "name": "value0",
        "type": "core::felt252"
      },
      {
        "name": "value1",
        "type": "core::felt252"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::bounds::Bounds",
    "members": [
      {
        "name": "lower",
        "type": "ekubo::types::i129::i129"
      },
      {
        "name": "upper",
        "type": "ekubo::types::i129::i129"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::keys::PositionKey",
    "members": [
      {
        "name": "salt",
        "type": "core::integer::u64"
      },
      {
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "bounds",
        "type": "ekubo::types::bounds::Bounds"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::position::Position",
    "members": [
      {
        "name": "liquidity",
        "type": "core::integer::u128"
      },
      {
        "name": "fees_per_liquidity_inside_last",
        "type": "ekubo::types::fees_per_liquidity::FeesPerLiquidity"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::interfaces::core::GetPositionWithFeesResult",
    "members": [
      {
        "name": "position",
        "type": "ekubo::types::position::Position"
      },
      {
        "name": "fees0",
        "type": "core::integer::u128"
      },
      {
        "name": "fees1",
        "type": "core::integer::u128"
      },
      {
        "name": "fees_per_liquidity_inside_current",
        "type": "ekubo::types::fees_per_liquidity::FeesPerLiquidity"
      }
    ]
  },
  {
    "type": "enum",
    "name": "core::option::Option::<core::integer::u256>",
    "variants": [
      {
        "name": "Some",
        "type": "core::integer::u256"
      },
      {
        "name": "None",
        "type": "()"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::interfaces::core::UpdatePositionParameters",
    "members": [
      {
        "name": "salt",
        "type": "core::integer::u64"
      },
      {
        "name": "bounds",
        "type": "ekubo::types::bounds::Bounds"
      },
      {
        "name": "liquidity_delta",
        "type": "ekubo::types::i129::i129"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::types::delta::Delta",
    "members": [
      {
        "name": "amount0",
        "type": "ekubo::types::i129::i129"
      },
      {
        "name": "amount1",
        "type": "ekubo::types::i129::i129"
      }
    ]
  },
  {
    "type": "struct",
    "name": "ekubo::interfaces::core::SwapParameters",
    "members": [
      {
        "name": "amount",
        "type": "ekubo::types::i129::i129"
      },
      {
        "name": "is_token1",
        "type": "core::bool"
      },
      {
        "name": "sqrt_ratio_limit",
        "type": "core::integer::u256"
      },
      {
        "name": "skip_ahead",
        "type": "core::integer::u32"
      }
    ]
  },
  {
    "type": "interface",
    "name": "ekubo::interfaces::core::ICore",
    "items": [
      {
        "type": "function",
        "name": "set_withdrawal_only_mode",
        "inputs": [],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "get_withdrawal_only_mode",
        "inputs": [],
        "outputs": [
          {
            "type": "core::bool"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_protocol_fees_collected",
        "inputs": [
          {
            "name": "token",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u128"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_locker_state",
        "inputs": [
          {
            "name": "id",
            "type": "core::integer::u32"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::interfaces::core::LockerState"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_pool_price",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::pool_price::PoolPrice"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_pool_liquidity",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u128"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_pool_fees_per_liquidity",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::fees_per_liquidity::FeesPerLiquidity"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_pool_fees_per_liquidity_inside",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "bounds",
            "type": "ekubo::types::bounds::Bounds"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::fees_per_liquidity::FeesPerLiquidity"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_pool_tick_liquidity_delta",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "index",
            "type": "ekubo::types::i129::i129"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::i129::i129"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_pool_tick_liquidity_net",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "index",
            "type": "ekubo::types::i129::i129"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u128"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_pool_tick_fees_outside",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "index",
            "type": "ekubo::types::i129::i129"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::fees_per_liquidity::FeesPerLiquidity"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_position",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "position_key",
            "type": "ekubo::types::keys::PositionKey"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::position::Position"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_position_with_fees",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "position_key",
            "type": "ekubo::types::keys::PositionKey"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::interfaces::core::GetPositionWithFeesResult"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_reserves",
        "inputs": [
          {
            "name": "token",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "get_saved_balance",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "token",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "cache_key",
            "type": "core::integer::u64"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u128"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "next_initialized_tick",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "from",
            "type": "ekubo::types::i129::i129"
          },
          {
            "name": "skip_ahead",
            "type": "core::integer::u32"
          }
        ],
        "outputs": [
          {
            "type": "(ekubo::types::i129::i129, core::bool)"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "prev_initialized_tick",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "from",
            "type": "ekubo::types::i129::i129"
          },
          {
            "name": "skip_ahead",
            "type": "core::integer::u32"
          }
        ],
        "outputs": [
          {
            "type": "(ekubo::types::i129::i129, core::bool)"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "withdraw_protocol_fees",
        "inputs": [
          {
            "name": "recipient",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "token",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "amount",
            "type": "core::integer::u128"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "lock",
        "inputs": [
          {
            "name": "data",
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "outputs": [
          {
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "withdraw",
        "inputs": [
          {
            "name": "token_address",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "recipient",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "amount",
            "type": "core::integer::u128"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "save",
        "inputs": [
          {
            "name": "token_address",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "cache_key",
            "type": "core::integer::u64"
          },
          {
            "name": "recipient",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "amount",
            "type": "core::integer::u128"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u128"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "deposit",
        "inputs": [
          {
            "name": "token_address",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u128"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "load",
        "inputs": [
          {
            "name": "token_address",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "cache_key",
            "type": "core::integer::u64"
          },
          {
            "name": "amount",
            "type": "core::integer::u128"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u128"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "initialize_pool",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "initial_tick",
            "type": "ekubo::types::i129::i129"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "maybe_initialize_pool",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "initial_tick",
            "type": "ekubo::types::i129::i129"
          }
        ],
        "outputs": [
          {
            "type": "core::option::Option::<core::integer::u256>"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "update_position",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "params",
            "type": "ekubo::interfaces::core::UpdatePositionParameters"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::delta::Delta"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "collect_fees",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "salt",
            "type": "core::integer::u64"
          },
          {
            "name": "bounds",
            "type": "ekubo::types::bounds::Bounds"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::delta::Delta"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "swap",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "params",
            "type": "ekubo::interfaces::core::SwapParameters"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::delta::Delta"
          }
        ],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "accumulate_as_fees",
        "inputs": [
          {
            "name": "pool_key",
            "type": "ekubo::types::keys::PoolKey"
          },
          {
            "name": "amount0",
            "type": "core::integer::u128"
          },
          {
            "name": "amount1",
            "type": "core::integer::u128"
          }
        ],
        "outputs": [
          {
            "type": "ekubo::types::delta::Delta"
          }
        ],
        "state_mutability": "external"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::ClassHashReplaced",
    "kind": "struct",
    "members": [
      {
        "name": "new_class_hash",
        "type": "core::starknet::class_hash::ClassHash",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::ProtocolFeesPaid",
    "kind": "struct",
    "members": [
      {
        "name": "pool_key",
        "type": "ekubo::types::keys::PoolKey",
        "kind": "data"
      },
      {
        "name": "position_key",
        "type": "ekubo::types::keys::PositionKey",
        "kind": "data"
      },
      {
        "name": "delta",
        "type": "ekubo::types::delta::Delta",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::ProtocolFeesWithdrawn",
    "kind": "struct",
    "members": [
      {
        "name": "recipient",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "amount",
        "type": "core::integer::u128",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::PoolInitialized",
    "kind": "struct",
    "members": [
      {
        "name": "pool_key",
        "type": "ekubo::types::keys::PoolKey",
        "kind": "data"
      },
      {
        "name": "initial_tick",
        "type": "ekubo::types::i129::i129",
        "kind": "data"
      },
      {
        "name": "sqrt_ratio",
        "type": "core::integer::u256",
        "kind": "data"
      },
      {
        "name": "call_points",
        "type": "core::integer::u8",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::PositionUpdated",
    "kind": "struct",
    "members": [
      {
        "name": "locker",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "pool_key",
        "type": "ekubo::types::keys::PoolKey",
        "kind": "data"
      },
      {
        "name": "params",
        "type": "ekubo::interfaces::core::UpdatePositionParameters",
        "kind": "data"
      },
      {
        "name": "delta",
        "type": "ekubo::types::delta::Delta",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::PositionFeesCollected",
    "kind": "struct",
    "members": [
      {
        "name": "pool_key",
        "type": "ekubo::types::keys::PoolKey",
        "kind": "data"
      },
      {
        "name": "position_key",
        "type": "ekubo::types::keys::PositionKey",
        "kind": "data"
      },
      {
        "name": "delta",
        "type": "ekubo::types::delta::Delta",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::Swapped",
    "kind": "struct",
    "members": [
      {
        "name": "locker",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "pool_key",
        "type": "ekubo::types::keys::PoolKey",
        "kind": "data"
      },
      {
        "name": "params",
        "type": "ekubo::interfaces::core::SwapParameters",
        "kind": "data"
      },
      {
        "name": "delta",
        "type": "ekubo::types::delta::Delta",
        "kind": "data"
      },
      {
        "name": "sqrt_ratio_after",
        "type": "core::integer::u256",
        "kind": "data"
      },
      {
        "name": "tick_after",
        "type": "ekubo::types::i129::i129",
        "kind": "data"
      },
      {
        "name": "liquidity_after",
        "type": "core::integer::u128",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::SavedBalance",
    "kind": "struct",
    "members": [
      {
        "name": "to",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "cache_key",
        "type": "core::integer::u64",
        "kind": "data"
      },
      {
        "name": "amount",
        "type": "core::integer::u128",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::LoadedBalance",
    "kind": "struct",
    "members": [
      {
        "name": "from",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "cache_key",
        "type": "core::integer::u64",
        "kind": "data"
      },
      {
        "name": "amount",
        "type": "core::integer::u128",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "ekubo::core::Core::Event",
    "kind": "enum",
    "variants": [
      {
        "name": "ClassHashReplaced",
        "type": "ekubo::core::Core::ClassHashReplaced",
        "kind": "nested"
      },
      {
        "name": "ProtocolFeesPaid",
        "type": "ekubo::core::Core::ProtocolFeesPaid",
        "kind": "nested"
      },
      {
        "name": "ProtocolFeesWithdrawn",
        "type": "ekubo::core::Core::ProtocolFeesWithdrawn",
        "kind": "nested"
      },
      {
        "name": "PoolInitialized",
        "type": "ekubo::core::Core::PoolInitialized",
        "kind": "nested"
      },
      {
        "name": "PositionUpdated",
        "type": "ekubo::core::Core::PositionUpdated",
        "kind": "nested"
      },
      {
        "name": "PositionFeesCollected",
        "type": "ekubo::core::Core::PositionFeesCollected",
        "kind": "nested"
      },
      {
        "name": "Swapped",
        "type": "ekubo::core::Core::Swapped",
        "kind": "nested"
      },
      {
        "name": "SavedBalance",
        "type": "ekubo::core::Core::SavedBalance",
        "kind": "nested"
      },
      {
        "name": "LoadedBalance",
        "type": "ekubo::core::Core::LoadedBalance",
        "kind": "nested"
      }
    ]
  }
]

```

</details>
