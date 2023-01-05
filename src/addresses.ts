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
        ArrakisV2Implementation: "0xb5C3B286dD591282Fe87Dfab0613488e1b6B09Ba",
        ArrakisV2Beacon: "0x891E7E4baFfeF0ef7bc4b1E85d122bDd7363b8B3",
        ArrakisV2Factory: "0x055B6d3919042Be29C5F044A55529933e1273A88",
        ArrakisV2Helper: "0xccEe73eA4c7a42491c68FEa78B1BDDD1A35C8d9C",
        ArrakisV2Resolver: "0x4bc385b1dDf0121CC40A0715CfD3beFE52f905f5",
      };
    case "mainnet":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        WMATIC: "",
        USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        ArrakisV2Implementation: "0xb5C3B286dD591282Fe87Dfab0613488e1b6B09Ba",
        ArrakisV2Beacon: "0x891E7E4baFfeF0ef7bc4b1E85d122bDd7363b8B3",
        ArrakisV2Factory: "0x055B6d3919042Be29C5F044A55529933e1273A88",
        ArrakisV2Helper: "0xccEe73eA4c7a42491c68FEa78B1BDDD1A35C8d9C",
        ArrakisV2Resolver: "0x4bc385b1dDf0121CC40A0715CfD3beFE52f905f5",
      };
    case "polygon":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
        USDC: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
        ArrakisV2Implementation: "0xb5C3B286dD591282Fe87Dfab0613488e1b6B09Ba",
        ArrakisV2Beacon: "0x891E7E4baFfeF0ef7bc4b1E85d122bDd7363b8B3",
        ArrakisV2Factory: "0x055B6d3919042Be29C5F044A55529933e1273A88",
        ArrakisV2Helper: "0xccEe73eA4c7a42491c68FEa78B1BDDD1A35C8d9C",
        ArrakisV2Resolver: "0x4bc385b1dDf0121CC40A0715CfD3beFE52f905f5",
      };
    case "optimism":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0x4200000000000000000000000000000000000006",
        WMATIC: "",
        USDC: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
        ArrakisV2Implementation: "0xb5C3B286dD591282Fe87Dfab0613488e1b6B09Ba",
        ArrakisV2Beacon: "0x891E7E4baFfeF0ef7bc4b1E85d122bDd7363b8B3",
        ArrakisV2Factory: "0x055B6d3919042Be29C5F044A55529933e1273A88",
        ArrakisV2Helper: "0xccEe73eA4c7a42491c68FEa78B1BDDD1A35C8d9C",
        ArrakisV2Resolver: "0x4bc385b1dDf0121CC40A0715CfD3beFE52f905f5",
      };
    case "arbitrum":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
        WMATIC: "",
        USDC: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
        ArrakisV2Implementation: "0xb5C3B286dD591282Fe87Dfab0613488e1b6B09Ba",
        ArrakisV2Beacon: "0x891E7E4baFfeF0ef7bc4b1E85d122bDd7363b8B3",
        ArrakisV2Factory: "0x055B6d3919042Be29C5F044A55529933e1273A88",
        ArrakisV2Helper: "0xccEe73eA4c7a42491c68FEa78B1BDDD1A35C8d9C",
        ArrakisV2Resolver: "0x4bc385b1dDf0121CC40A0715CfD3beFE52f905f5",
      };
    case "goerli":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        WETH: "",
        WMATIC: "",
        USDC: "",
        ArrakisV2Implementation: "0xb5C3B286dD591282Fe87Dfab0613488e1b6B09Ba",
        ArrakisV2Beacon: "0x891E7E4baFfeF0ef7bc4b1E85d122bDd7363b8B3",
        ArrakisV2Factory: "0x055B6d3919042Be29C5F044A55529933e1273A88",
        ArrakisV2Helper: "0xccEe73eA4c7a42491c68FEa78B1BDDD1A35C8d9C",
        ArrakisV2Resolver: "0x4bc385b1dDf0121CC40A0715CfD3beFE52f905f5",
      };
    default:
      throw new Error(`No addresses for Network: ${network}`);
  }
};
