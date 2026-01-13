---
description: Every interaction with Ekubo starts with a call to `#lock`
---

# 💸 "Till" pattern

Ekubo is a singleton contract that utilizes the "till" pattern. All pools and tokens are represented as state in the singleton. The till pattern was [publicly introduced](https://www.youtube.com/watch?v=xFp8RlRq0qU) at EthCC\[5] and is also described [here](https://github.com/OpenZeppelin/openzeppelin-contracts/issues/4361#issuecomment-1595095135). When interacting with pools in Ekubo, all token payments may be deferred until you have completed all the Core operations (e.g. swap, add liquidity, collect fees).

{% hint style="info" %}
Even though the entrypoint for all methods is named `#lock`, Ekubo protocol supports reentrancy. Locks can be nested, meaning any contract you call can also interact with Ekubo.
{% endhint %}
