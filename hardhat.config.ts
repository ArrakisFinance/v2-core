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
const PK_TEST = process.env.PK_TEST;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",

  // hardhat-deploy
  namedAccounts: {
    deployer: {
      default: 0,
    },
    arrakisMultiSig: {
      default: 1,
      polygon: "0xDEb4C33D5C3E7e32F55a9D6336FE06010E40E3AB",
    },
    owner: {
      default: 2,
      polygon: "0xF869f0eBDDAa33d7aa394c2c612E6e5a6A64fDA4",
    },
    arrakisTreasury: {
      default: 3,
      polygon: "0xDEb4C33D5C3E7e32F55a9D6336FE06010E40E3AB",
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
    goerli: {
      accounts: PK_TEST ? [PK_TEST] : [],
      chainId: 5,
      url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_ID}`,
    },
  },

  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          optimizer: { enabled: true, runs: 50 },
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
