import { HardhatUserConfig } from "hardhat/config";

// PLUGINS
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-deploy";
import "solidity-coverage";
import "hardhat-gas-reporter";

import { ethers } from "ethers";

// Process Env Variables
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + "/.env" });
const ALCHEMY_ID = process.env.ALCHEMY_ID;
const PK = process.env.PK;
const TEST_PK = process.env.TEST_PK;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",

  // hardhat-deploy
  namedAccounts: {
    deployer: {
      default: 0,
    },
    arrakisMultiSig: {
      default: 1,
      polygon: "0xd06a7cc1a162fDfB515595A2eC1c47B75743C381",
      mainnet: "0xb9229ea965FC84f21b63791efC643b2c7ffB77Be",
      optimism: "0x283824e5A6378EaB2695Be7d3cb0919186e37D7C",
      arbitrum: "0x64520Dc190b5015E7d48E87273f6EE69197Cd798",
    },
    owner: {
      default: 2,
      polygon: "0xDEb4C33D5C3E7e32F55a9D6336FE06010E40E3AB",
      mainnet: "0x5108EF86cF493905BcD35A3736e4B46DeCD7de58",
      optimism: "0x8636600A864797Aa7ac8807A065C5d8BD9bA3Ccb",
      arbitrum: "0x77BADa8FC2A478f1bc1E1E4980916666187D0dF7",
    },
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  networks: {
    hardhat: {
      forking: {
        url: `https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_ID}`,
        blockNumber: 25594591, // ether price $4,168.96
      },
      accounts: {
        accountsBalance: ethers.utils.parseEther("10000").toString(),
      },
    },
    mainnet: {
      accounts: PK ? [PK] : [],
      chainId: 1,
      url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_ID}`,
    },
    polygon: {
      accounts: PK ? [PK] : [],
      chainId: 137,
      url: `https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_ID}`,
    },
    optimism: {
      accounts: PK ? [PK] : [],
      chainId: 10,
      url: `https://opt-mainnet.g.alchemy.com/v2/${ALCHEMY_ID}`,
    },
    arbitrum: {
      accounts: PK ? [PK] : [],
      chainId: 42161,
      url: `https://arb-mainnet.g.alchemy.com/v2/${ALCHEMY_ID}`,
    },
    goerli: {
      accounts: TEST_PK ? [TEST_PK] : [],
      chainId: 5,
      url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_ID}`,
    },
  },

  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          optimizer: { enabled: true, runs: 833 },
        },
      },
    ],
  },

  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
};

export default config;
