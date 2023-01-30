/* eslint-disable @typescript-eslint/naming-convention */
export interface Addresses {
  UniswapV3Factory: string;
  SwapRouter: string;
  WETH: string;
  WMATIC: string;
  USDC: string;
  ArrakisV2Implementation: string;
  ArrakisV2Beacon: string;
  ArrakisV2Factory: string;
  ArrakisV2Helper: string;
  ArrakisV2Resolver: string;
}

export const getAddresses = (network: string): Addresses => {
  switch (network) {
    case "hardhat":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
        USDC: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
        ArrakisV2Implementation: "",
        ArrakisV2Beacon: "",
        ArrakisV2Factory: "",
        ArrakisV2Helper: "",
        ArrakisV2Resolver: "",
      };
    case "mainnet":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        WMATIC: "",
        USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        ArrakisV2Implementation: "",
        ArrakisV2Beacon: "",
        ArrakisV2Factory: "",
        ArrakisV2Helper: "",
        ArrakisV2Resolver: "",
      };
    case "polygon":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
        USDC: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
        ArrakisV2Implementation: "",
        ArrakisV2Beacon: "",
        ArrakisV2Factory: "",
        ArrakisV2Helper: "",
        ArrakisV2Resolver: "",
      };
    case "optimism":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0x4200000000000000000000000000000000000006",
        WMATIC: "",
        USDC: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
        ArrakisV2Implementation: "",
        ArrakisV2Beacon: "",
        ArrakisV2Factory: "",
        ArrakisV2Helper: "",
        ArrakisV2Resolver: "",
      };
    case "arbitrum":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
        WMATIC: "",
        USDC: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
        ArrakisV2Implementation: "",
        ArrakisV2Beacon: "",
        ArrakisV2Factory: "",
        ArrakisV2Helper: "",
        ArrakisV2Resolver: "",
      };
    case "goerli":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "",
        WMATIC: "",
        USDC: "",
        ArrakisV2Implementation: "",
        ArrakisV2Beacon: "",
        ArrakisV2Factory: "",
        ArrakisV2Helper: "",
        ArrakisV2Resolver: "",
      };
    default:
      throw new Error(`No addresses for Network: ${network}`);
  }
};
