import { HardhatUserConfig, task } from "hardhat/config";
import deployPool from "./tasks/deployPool";

// PLUGINS
import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";
import "solidity-coverage";
import "hardhat-gas-reporter";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
// import "@typechain/hardhat";

// Process Env Variables
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + "/.env" });
const ALCHEMY_ID = process.env.ALCHEMY_ID;
const PK = process.env.PK;
const TEST_PK = process.env.TEST_PK;

deployPool();

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  etherscan: {
    apiKey: {
      avalanche: `${process.env.SNOWTRACE_API_KEY}`,
      bsc: `${process.env.BSC_SCAN_API_KEY}`,
      arbitrumOne: `${process.env.ARBI_SCAN_API_KEY}`,
    },
  },

  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
      accounts: [
        {
          privateKey: `0x${process.env.MAINNET_PRIVATE_KEY}`,
          balance: "2000000000000000000000000",
        },
      ],

      forking: {
        url: `${process.env["ARBITRUM_ARCHIVE_NODE_URL"]}`,
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
      accounts: [`0x${process.env.MAINNET_PRIVATE_KEY}`],
      chainId: 42161,
      url: `${process.env["ARBITRUM_ARCHIVE_NODE_URL"]}`,
    },
    binance: {
      accounts: PK ? [PK] : [],
      chainId: 56,
      url: "https://bsc-dataseed.binance.org/",
    },
    goerli: {
      accounts: TEST_PK ? [TEST_PK] : [],
      chainId: 5,
      url: `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_ID}`,
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
  //   typechain: {
  //     outDir: "typechain",
  //     target: "ethers-v5",
  //     externalArtifacts: ["**/openzeppelin/!(*.dbg).ts"],
  //   },
  // contractSizer: {
  // alphaSort: true,
  // runOnCompile: true,
  // strict: true,
  // },
};

export default config;
