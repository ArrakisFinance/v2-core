/* eslint-disable @typescript-eslint/naming-convention */
export interface Addresses {
  Gelato: string;
  UniswapV3Factory: string;
  SwapRouter: string;
  TestPool: string;
  WETH: string;
  WMATIC: string;
  USDC: string;
}

export const getAddresses = (network: string): Addresses => {
  switch (network) {
    case "hardhat":
      return {
        Gelato: "0x7598e84B2E114AB62CAB288CE5f7d5f6bad35BbA",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        TestPool: "0x45dDa9cb7c25131DF268515131f647d726f50608",
        WETH: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
        USDC: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
      };
    case "mainnet":
      return {
        Gelato: "0x3CACa7b48D0573D793d3b0279b5F0029180E83b6",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        TestPool: "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640",
        WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        WMATIC: "",
        USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      };
    case "polygon":
      return {
        Gelato: "0x7598e84B2E114AB62CAB288CE5f7d5f6bad35BbA",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        TestPool: "0x45dDa9cb7c25131DF268515131f647d726f50608",
        WETH: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
        USDC: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
      };
    case "optimism":
      return {
        Gelato: "0x01051113D81D7d6DA508462F2ad6d7fD96cF42Ef",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "",
        TestPool: "0x85149247691df622eaf1a8bd0cafd40bc45154a9",
        WETH: "0x4200000000000000000000000000000000000006",
        WMATIC: "",
        USDC: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
      };
    case "goerli":
      return {
        Gelato: "0x683913B3A32ada4F8100458A3E1675425BdAa7DF",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "",
        TestPool: "",
        WETH: "",
        WMATIC: "",
        USDC: "",
      };
    default:
      throw new Error(`No addresses for Network: ${network}`);
  }
};
