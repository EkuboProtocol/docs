---
description: >-
  Messages that may be emitted by the contracts when your transaction fails and
  their meanings
---

# Error Codes

## Core

### NOT\_LOCKED

You did not call the `#lock` method on `ICore` before calling a method that requires it, e.g. `#swap` or `#update_position`.

### NOT\_LOCKER

Core is locked, but the caller of the method is not the most recent locker.

### NOT\_ZEROED

You did not zero out all the deltas before releasing the lock, i.e. returning from the `#locked`.

This means you did not pay the sum of the deltas generated from all your actions, e.g. if you made only a single swap you either did not pay the required amount of input token or take the received amount of output token. Make sure to use the amounts returned from these calls, rather than amounts passed in from elsewhere.

### ALREADY\_INITIALIZED

The pool is already initialized. Prefer to call `#maybe_initialize_pool` if you would like to handle this more gracefully.

### NOT\_INITIALIZED

A method was called for a pool that was not initialized.

### LIMIT\_DIRECTION

The `sqrt_ratio_limit` parameter given to a swap must be in the direction of the swap. For example, if your swap increasing the `token0` balance of the pool, your `sqrt_ratio_limit` parameter must be greater than the current `sqrt_ratio`.

### LIMIT\_MAG

The magnitude of your `sqrt_ratio_limit` parameter exceeds the minimum or maximum value, which are `18446748437148339061` and `6277100250585753475930931601400621808602321654880405518632` respectively.

### MUST\_COLLECT\_FEES

You must collect all the fees for a position before withdrawing all the liquidity.

### NEXT\_FROM\_MAX

You cannot call `#next_initialized_tick` starting from the maximum tick.

### PREV\_FROM\_MIN

You cannot call `#prev_initialized_tick` starting from the minimum tick.

### INSUFFICIENT\_RESERVES

You attempted to withdraw more of a token than the last known balance of the core contract.

### WITHDRAWALS\_ONLY

The contract is currently in withdrawals only mode, meaning you can only perform actions that reduce the core contract balance.

### BALANCE\_LT\_RESERVE

This means the core contract got into an invalid state where the token balance is less than the last recognized balance, which can happen if the token is rebasing or otherwise not well-behaved.

### DELTA\_EXCEEDED\_MAX

The delta for a token's balance cannot exceed the maximum u128 value. In general, tokens that have total supply greater than the max u128 may encounter issues and should be avoided.

### INSUFFICIENT\_SAVED\_BALANCE

You attempted to load more than was saved for a saved balance.

## Positions

### BALANCE\_OVERFLOW

The balance of the token exceeds the max u128 value. The positions contract only works with tokens that have a total supply less than the max u128 value.

### MIN\_TOKEN0

When withdrawing liquidity, your slippage tolerance for `token0` was not met, i.e. not enough `token0` was withdrawn.

### MIN\_TOKEN1

When withdrawing liquidity, your slippage tolerance for `token1` was not met, i.e. not enough `token1` was withdrawn.

### LIQUIDITY\_MUST\_BE\_ZERO

When burning an NFT using the safer version, which requires you to specify the pool key, the liquidity was not zero.

### UNAUTHORIZED

You must be approved or the owner of an NFT or the operator of an account to modify the related position(s).

### MIN\_LIQUIDITY

The minimum size of the position was not met with the given amount of tokens. This is the slippage check for adding liquidity.



