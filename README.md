# Vault V1 Core

A shared fungible (ERC20) position for Uniswap V3 liquidity management and optimization. ArrakisVaultV1 is auto-compounded by Gelato Network keepers to reinvest accrued fees into the position. For vaults with a `manager` role set, manager may call `executiveRebalance` which will adjust the price range within which vault liquidity is deployed to the underlying Uniswap V3 pool.

Vaults can be permissionlessly deployed and managed by anyone on any existing Uniswap V3 pair, via the ArrakisFactoryV1 contract. Due to sensitivity of the `manager` role, only vaults explicitly under Arrakis DAO management or without any manager can be safely trusted, in the absence of further information.

(see [docs](https://docs-g-uni.gelato.network) for more info)

# test

yarn

yarn compile

yarn test
