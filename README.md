# V2 Core

Arrakis Vaults Version 2, Core Smart Contracts.

[Read the full developer documentation](https://docs.arrakis.fi)

## About

Arrakis V2 Core enables anyone to:

- create an `ArrakisV2` vault instance that manages holdings of a given token pair and issues ERC20 shares to depositor(s) of the token pair

- dispatch and collect vault's token pair holdings to/from Uniswap V3 Liquidity Positions via a settable `manager` account (or smart contract)

- configure and control important vault setup parameters (manager, pools, swap routers, mint restrictions) via the vault `owner` account (or smart contract)

#### ArrakisV2.sol

The ERC20 vault smart contract at the heart of this LP management system. A vault collects assets in a given token pair and delegates a manager smart contract to deploy vault capital in and out of an arbitrary collection of Uniswap V3 LP Positions for that token pair. Utilize the ERC20 tokenization of the position to aggregate liquidity from multiple shareholders, or create a "private" vault exclusively for a single depositor (see `restrictedMint` property).

#### ArrakisV2Factory.sol

The entry-point for deploying ArrakisV2 vault instances. Deploy vaults for any token pair and configure the owner, manager, and other initial parameters when calling `deployVault`

The Arrakis V2 Core contracts are thus neutral concentrated liquidity management infrastructure which anyone can deploy, configure and use freely- no added fees or haircut. Anyone can build "Active Liquidity Management" products on Arrakis V2 infrastructure for both private and public use-cases, and implement their own custom fee fee models and manager systems. While vaults don't have any hardcoded protocol fees, the manager role may still optionally set a fee parameter to take some proportion (or all) of the fees earned by the vault's Uniswap LP positions.

## Setup

Create `.env` file and add `ALCHEMY_ID` (for all relevant environment variables, see `.env.example`)

Repo uses yarn for package management. Don't have yarn? [see here](https://classic.yarnpkg.com/lang/en/docs/install/#mac-stable)

## Test

install dependencies:

```
yarn
```

compile contracts:

```
yarn compile
```

run tests:

```
yarn test
```

## Audits

Two security audits were performed on the smart contracts in this repository. The auditors were [WatchPug](https://www.watchpug.org/) and [Statemind](https://statemind.io/) and the comprehensive audit reports can be found in the `audit/` directory.

## Licensing

The primary license for Arrakis V2 Core is the Business Source License 1.1 (BUSL-1.1), see LICENSE. However, some files are dual licensed under MIT or GPL-2.0-or-later. The respective license of each smart contract is defined by its SPDX header.
