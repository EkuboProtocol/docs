---
description: Dated snapshot of who owns the Ekubo EVM Positions, Orders and Auctions peripheral contracts on each chain, with the ownership-transfer transactions and DAO owner proxies
title: "Peripheral-contract ownership (snapshot 2026-10-09)"
---

Companion to the [ownership update of 9 October 2026](/products/governance/#peripheral-contract-ownership-update-9-october-2026). Every row is verifiable on the chain's public explorer: the transaction emits `OwnershipTransferred(previousOwner, newOwner)` from the contract and the contract's `owner()` now returns the new owner. Owner proxies are controlled from Ethereum by the `StarknetOwnerProxy` [`0x1e0ef4162e42c9bf820c307218c4e41ccca6e9cc`](https://etherscan.io/address/0x1e0ef4162e42c9bf820c307218c4e41ccca6e9cc), which only the Ekubo DAO Governor on Starknet ([`0x053499f7aa2706395060fe72d00388803fb2dcc111429891ad7b2d9dcea29acd`](https://voyager.online/contract/0x053499f7aa2706395060fe72d00388803fb2dcc111429891ad7b2d9dcea29acd)) can drive. Previous owner of every transferred contract: the Ekubo, Inc. company key `0x00000C771F6176268D5A9846E0956C3eF58597A1`.

## 1. Ownership transfers (33)

| #   | Chain (ID)             | Contract                            | Address                                      | New owner (DAO owner proxy)                  | Transaction                                                          | Block     |
| --- | ---------------------- | ----------------------------------- | -------------------------------------------- | -------------------------------------------- | -------------------------------------------------------------------- | --------- |
| 1   | Ethereum (1)           | Orders v3.1.1                       | `0x3325428adB409c239E88ca472F50b0efe00E98B4` | `0x1e0ef4162e42c9bf820c307218c4e41ccca6e9cc` | `0xc00a14226876f8e0b73926ba540889167df02e857b12325c0b5c5818ef644bac` | 26150761  |
| 2   | Ethereum (1)           | Positions v3.2.0                    | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | `0x1e0ef4162e42c9bf820c307218c4e41ccca6e9cc` | `0x4cf2c2e5dc7346fd1db1f03c740cad384f52d5c07ade36adabc899ba3e118ede` | 26150762  |
| 3   | Ethereum (1)           | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0x1e0ef4162e42c9bf820c307218c4e41ccca6e9cc` | `0x350604113d67aea5e56999e1c250b2f849e04aa47652d772c9ec4469f7e4dba4` | 26150763  |
| 4   | Ethereum (1)           | Auctions                            | `0xcb4e1b5fb7b120db0815afa63453c969136c0ec9` | `0x1e0ef4162e42c9bf820c307218c4e41ccca6e9cc` | `0x9fd9e1135bcf79f50003270f6028bff0164c469891d7b1b164c261bd32b10c8b` | 26150764  |
| 5   | Ethereum (1)           | Orders (pre-recompile, oldOrdersV3) | `0xfF6cF0Ca6d7a30a60539AcD4bB20B3df84EA0644` | `0x1e0ef4162e42c9bf820c307218c4e41ccca6e9cc` | `0x81554e3fed59c25f5a341bd4115b180c7437dd3fcc2e6346278badefca1d8775` | 26150765  |
| 6   | Base (8453)            | Positions v3.1.1                    | `0x02d9876a21af7545f8632c3af76ec90b5ad4b66d` | `0xd46197c8c5cba977c4c287f04ddc77f2dc105067` | `0x1bd1cead88b05ee5570217552d27a5e9d5cd929d6d8824166296893e0fc6d84b` | 52355194  |
| 7   | Base (8453)            | Orders v3.1.1                       | `0x3325428adB409c239E88ca472F50b0efe00E98B4` | `0xd46197c8c5cba977c4c287f04ddc77f2dc105067` | `0x51eb03c0863ae551ae394543d524f4754bf3730cfe7bd47b894ad66ad5175f43` | 52355326  |
| 8   | Base (8453)            | Positions v3.2.0                    | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | `0xd46197c8c5cba977c4c287f04ddc77f2dc105067` | `0x1d93e2cb8d3b6309c81daa8d47300d60d3fbfa83796c9c253f8834fb6ea0fee3` | 52355372  |
| 9   | Base (8453)            | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0xd46197c8c5cba977c4c287f04ddc77f2dc105067` | `0x55c09d263f3f640de543f0a7fd4272c50d874f5e4fd47a7995f8c79b560723ab` | 52355378  |
| 10  | OP Mainnet (10)        | Positions v3.2.0                    | `0xa2971e0c37cfdb13ae8440a0c94ef1a1af39e326` | `0xcad6e08e0532d523c10825821d10e3f7c845b0c0` | `0x0a05e1b03f9c315dbf0c7d8868c4e57033dd7e550ed6e055561a951dea04a61b` | 157950480 |
| 11  | OP Mainnet (10)        | Orders v3.2.0                       | `0x9bb520b6192f71ec3d015c8a74f914f9c94bf794` | `0xcad6e08e0532d523c10825821d10e3f7c845b0c0` | `0x15707d5c173bc5eb7db62fe1ebc28b3b631f0e394cd43827ab6d465302783886` | 157950495 |
| 12  | Arbitrum One (42161)   | Positions v3.1.1                    | `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D` | `0x2ed25dec49800edb237de812ab9a4c37b74d3282` | `0x048689ea932ba831db2932dbec5f52b90a801ff3be69393548ad52835845baa9` | 513021097 |
| 13  | Arbitrum One (42161)   | Orders v3.1.1                       | `0x3325428adB409c239E88ca472F50b0efe00E98B4` | `0x2ed25dec49800edb237de812ab9a4c37b74d3282` | `0x45478972fd80055908cc3321749c55d89fe473c7e44cd5eaf37861706c8a2459` | 513021109 |
| 14  | Arbitrum One (42161)   | Positions v3.2.0                    | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | `0x2ed25dec49800edb237de812ab9a4c37b74d3282` | `0xac4c1015c70b06e58c70c9b8e67a5942ae0e2b50a22dd4ad0d4866283cfa7040` | 513021122 |
| 15  | Arbitrum One (42161)   | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0x2ed25dec49800edb237de812ab9a4c37b74d3282` | `0x57b6ba1062d08080f77d8a350ccae7183295d96fe771b5c42585a41dd59b99f9` | 513021135 |
| 16  | Arbitrum One (42161)   | Auctions                            | `0xcb4e1b5fb7b120db0815afa63453c969136c0ec9` | `0x2ed25dec49800edb237de812ab9a4c37b74d3282` | `0x4f2e0e8cf987ff995e25c2fc4c7b4db2215fe47be89a78e3131d2afa8ad9c473` | 513021144 |
| 17  | Arbitrum One (42161)   | Orders (pre-recompile, oldOrdersV3) | `0xfF6cF0Ca6d7a30a60539AcD4bB20B3df84EA0644` | `0x2ed25dec49800edb237de812ab9a4c37b74d3282` | `0x8fd841293c5d8142259b03df8b2d8891be18d026aa5b7411982e2de83b7a7a03` | 513021158 |
| 18  | Robinhood Chain (4663) | Positions v3.1.1                    | `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D` | `0xcd87828f4f279d3c5fd7af531370298964b5eaab` | `0xb97097c8e1687749267c2f8481077034b5b0200cd90736b91939e97127ae6ffa` | 83681935  |
| 19  | Robinhood Chain (4663) | Orders v3.1.1                       | `0x3325428adB409c239E88ca472F50b0efe00E98B4` | `0xcd87828f4f279d3c5fd7af531370298964b5eaab` | `0x2d651858af9b3e8a744f99ab2d1c6d7574e1a042da2a1099573632cf60ead19e` | 83681969  |
| 20  | Unichain (130)         | Positions v3.2.0                    | `0xa2971e0c37cfdb13ae8440a0c94ef1a1af39e326` | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | `0xa3514cf24b664ed24b558d26d72ec2dce04d7301d3492002d016ac0d1acb7aa1` | 60752003  |
| 21  | Unichain (130)         | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | `0x9436d1fe0c59fda8b71706355a32485b76ba34a4f6e27d9407c7c296563ae324` | 60752064  |
| 22  | World Chain (480)      | Positions v3.2.0                    | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | `0xdaa3293aab3a1da4f63ffdf5d015bb761f84a065` | `0xcb46875c86080959bc3a357d9fe042dd452954868f163c37fbbdef9647ab3a8b` | 36082365  |
| 23  | World Chain (480)      | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0xdaa3293aab3a1da4f63ffdf5d015bb761f84a065` | `0x3177a9f774c21bc835b5f58b533aab4642d569c4ebecb723e229304a5af06a76` | 36082366  |
| 24  | Ink (57073)            | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | `0x6920fbc3d11ef5357df22e50e3c8ebdfb91c2ca89e9447b91ae406af57b9ec70` | 58002029  |
| 25  | Ink (57073)            | Positions v3.2.0                    | `0xa2971e0c37cfdb13ae8440a0c94ef1a1af39e326` | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | `0x7327d1a92a3871c898f10f7d47035d5e44c305d4442d043aedb73bb50e7b8b89` | 58001971  |
| 26  | MegaETH (4326)         | Positions v3.1.1                    | `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D` | `0x112ae742db22d6a579cf47b225f17c716d27c535` | `0x6ef1f56022d4af7e9f2ff6073d161572181c803b713c212f1b16f7469b7c8b61` | 28703374  |
| 27  | MegaETH (4326)         | Orders v3.1.1                       | `0x3325428adB409c239E88ca472F50b0efe00E98B4` | `0x112ae742db22d6a579cf47b225f17c716d27c535` | `0xd27a0a9bac830fd7dde0f716e4aca9ad247828c9b8350ee9854621e5b821164d` | 28703377  |
| 28  | MegaETH (4326)         | Positions v3.2.0                    | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | `0x112ae742db22d6a579cf47b225f17c716d27c535` | `0x0aa173494fa7634d22d34f5db802aa6872861c406bf21deba706bef6db725871` | 28703380  |
| 29  | MegaETH (4326)         | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0x112ae742db22d6a579cf47b225f17c716d27c535` | `0x4d590cdcf390a6c1b4c5b9330e544f73a7cf6bb8b9daeb1f1f7cb2d4c67308f1` | 28703382  |
| 30  | Gnosis (100)           | Positions v3.2.0                    | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | `0xdaa3293aab3a1da4f63ffdf5d015bb761f84a065` | `0x71df3a10468a9353a23449a4aa9d9af7f3fc11cf86824f27f766ba0dccc17791` | 48659496  |
| 31  | Gnosis (100)           | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0xdaa3293aab3a1da4f63ffdf5d015bb761f84a065` | `0x2733571831a082ca0e5332f866e6496eeabc7bb01af3047df61db7881fc40e4d` | 48659499  |
| 32  | Polygon PoS (137)      | Positions v3.2.0                    | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | `0x84a0973eebe3cadb78dfcac96dbbcf1d18b4e44026c2ea0cc0d5ef1f68777747` | 95197659  |
| 33  | Polygon PoS (137)      | Orders v3.2.0                       | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | `0xff2d65392180628b3cc514489b2153757ba208e0ed15f5ba8e1e1c49a254abcb` | 95197669  |

## 2. DAO owner proxies (11; 6 deployed in this migration)

| Chain (ID)             | Proxy type                                                               | Address                                      | Deployed               | Deployment transaction                                               |
| ---------------------- | ------------------------------------------------------------------------ | -------------------------------------------- | ---------------------- | -------------------------------------------------------------------- |
| Ethereum (1)           | StarknetOwnerProxy (Ethereum root, driven only by the Starknet Governor) | `0x1e0ef4162e42c9bf820c307218c4e41ccca6e9cc` | earlier (pre-existing) | —                                                                    |
| Base (8453)            | OPStackOwnerProxy                                                        | `0xd46197c8c5cba977c4c287f04ddc77f2dc105067` | earlier (pre-existing) | —                                                                    |
| OP Mainnet (10)        | OPStackOwnerProxy                                                        | `0xcad6e08e0532d523c10825821d10e3f7c845b0c0` | earlier (pre-existing) | —                                                                    |
| Arbitrum One (42161)   | ArbitrumOwnerProxy                                                       | `0x2ed25dec49800edb237de812ab9a4c37b74d3282` | earlier (pre-existing) | —                                                                    |
| Robinhood Chain (4663) | ArbitrumOwnerProxy                                                       | `0xcd87828f4f279d3c5fd7af531370298964b5eaab` | earlier (pre-existing) | —                                                                    |
| Unichain (130)         | OPStackOwnerProxy                                                        | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | 2026-10-08             | `0x8cbe6bfd1c8c8168cda3fd17d4099ca338767bbd0851ce5bd8ef3e99d184b260` |
| World Chain (480)      | OPStackOwnerProxy                                                        | `0xdaa3293aab3a1da4f63ffdf5d015bb761f84a065` | 2026-10-08             | `0x60b27139898f7e5ee392ee12953d904537bac8802e242d4587b6a1c7d6822be1` |
| Ink (57073)            | OPStackOwnerProxy                                                        | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | 2026-10-08             | `0xa96398d2cdc140b40b0be4b257c5983414dad51eb1db64faeed2f63d37d282fd` |
| MegaETH (4326)         | OPStackOwnerProxy                                                        | `0x112ae742db22d6a579cf47b225f17c716d27c535` | 2026-10-08             | `0x3d8bf877445c634312d8125c043184bd711201b984ec42b152437231a495c36d` |
| Gnosis (100)           | AMBOwnerProxy                                                            | `0xdaa3293aab3a1da4f63ffdf5d015bb761f84a065` | 2026-10-08             | `0xc04ea38ac53d84e6a1c0d1701e817aae8b6a6746f146985b64acc1cfacf333c7` |
| Polygon PoS (137)      | FxPortalOwnerProxy                                                       | `0x6ed0533539b76d160f7a2c7630c1c85313d78dcc` | 2026-10-08             | `0xb569f85ed1431c3c9a6a3a41f78e71f590f05aa5530360d42e00d0657ebc48d9` |

Source code for all proxies is published and verified on the chains' explorers (Sourcify/Blockscout/Etherscan-family). The `OPStackOwnerProxy` and `ArbitrumOwnerProxy` sources are in the public [`EkuboProtocol/governance`](https://github.com/EkuboProtocol/governance) repository (`l1_proxy/`); the `AMBOwnerProxy` and `FxPortalOwnerProxy` sources are in that repository's [pull request #83](https://github.com/EkuboProtocol/governance/pull/83), pending merge.

## 3. Contracts that remain owned by the Ekubo, Inc. company key (6)

| Chain (ID)           | Contract                  | Address                                      | Owner powers                                                                                  |
| -------------------- | ------------------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------- |
| BNB Smart Chain (56) | Positions 192-bit v3.2.0  | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | withdraw accrued protocol fees to an owner-chosen recipient; set metadata; transfer ownership |
| BNB Smart Chain (56) | Orders 192-bit v3.2.0     | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | set metadata; transfer ownership (no funds)                                                   |
| Monad (143)          | Positions original v3.1.1 | `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D` | withdraw accrued protocol fees to an owner-chosen recipient; set metadata; transfer ownership |
| Monad (143)          | Orders original v3.1.1    | `0x3325428adB409c239E88ca472F50b0efe00E98B4` | set metadata; transfer ownership (no funds)                                                   |
| Monad (143)          | Positions 192-bit v3.2.0  | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | withdraw accrued protocol fees to an owner-chosen recipient; set metadata; transfer ownership |
| Monad (143)          | Orders 192-bit v3.2.0     | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | set metadata; transfer ownership (no funds)                                                   |

Reason: BNB Smart Chain and Monad have no canonical Ethereum message bridge, so no DAO owner proxy exists there yet. Their route is a separate pending company decision.

## 4. Snapshot evidence

Read-only state snapshot taken 2026-10-09 (per-chain block numbers below); all `owner()` values above re-read at these blocks; no ownership handover request is pending on any contract (`ownershipHandoverExpiresAt` = 0 for the company key on all 33 transferred contracts and for the DAO proxies).

| Chain (ID)             | Block     | Block hash                                                           | Time (UTC)                |
| ---------------------- | --------- | -------------------------------------------------------------------- | ------------------------- |
| Ethereum (1)           | 26150933  | `0xdeae404e96e65dbaf483164f75c4f7897fc6fbc86d4226dad3f0f0098f224095` | 2026-10-08T23:22:11+00:00 |
| Base (8453)            | 52356211  | `0xe0f588a2997990c5058469c9e72156d2f6165108f76ea08696e9e9185f4e019e` | 2026-10-08T23:22:49+00:00 |
| OP Mainnet (10)        | 157951481 | `0x4e639995626605ff1e8f248d377425e2a9c967e887f3a5a4c07ca2c35b3959c7` | 2026-10-08T23:22:19+00:00 |
| Arbitrum One (42161)   | 513026621 | `0x8299020c78b281cf39f97541488084a474ff9cb3de8034858c379df7e079dcf9` | 2026-10-08T23:22:51+00:00 |
| Robinhood Chain (4663) | 83697491  | `0xca9dd481ada20baaeecf638005c88831297dc429e3eeddc9ea61a992db83af23` | 2026-10-08T23:22:45+00:00 |
| Unichain (130)         | 60753388  | `0x2d9126d0f81649a5bbf898b8f2e418c325f5707ba1b20830f8e5637bf2e7856a` | 2026-10-08T23:22:27+00:00 |
| World Chain (480)      | 36083059  | `0x58bf090aa18e10a91204e4b446951bb33251a5e98af0f64d87fe542219f2cc3c` | 2026-10-08T23:22:37+00:00 |
| Ink (57073)            | 58003363  | `0xc6d705f87c83f925afe5794eef2f1793625c1ccfd775684412799a225fcea3ad` | 2026-10-08T23:22:54+00:00 |
| MegaETH (4326)         | 28704750  | `0xa799291b51c217103d944abb4d267f03ddfc7bd2de670a61220ff109f4d70aeb` | 2026-10-08T23:22:41+00:00 |
| Gnosis (100)           | 48659510  | `0x41f96b74ad598cba690d495d84cbad9b9f681396f104363d1e152820e2006c1d` | 2026-10-08T23:22:20+00:00 |
| Polygon PoS (137)      | 95197694  | `0x874fc87ff6610ba93475fc5a3abae14a502797c627fd418500faa22578c6ad6a` | 2026-10-08T23:22:30+00:00 |
| BNB Smart Chain (56)   | 126531070 | `0xa3098929db1acd8b15a9390a6fe79f2e54f817bf4d28e09bd24514b993e72102` | 2026-10-08T23:22:21+00:00 |
| Monad (143)            | 111740017 | `0xd7df9e0ac37f4fdf95088f2106e0f1cc3f93a3bded57f040dd7d82d9ef21ace6` | 2026-10-08T23:22:32+00:00 |

Immutable, ownerless contracts (Core, extensions, routers, lenses) are unaffected by this migration and have no owner on any chain.
