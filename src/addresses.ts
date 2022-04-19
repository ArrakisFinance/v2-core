/* eslint-disable @typescript-eslint/naming-convention */
interface Addresses {
  Gelato: string;
  UniswapV3Factory: string;
  ArrakisFeeTreasury: string;
}

export const getAddresses = (network: string): Addresses => {
  switch (network) {
    case "mainnet":
      return {
        Gelato: "0x3CACa7b48D0573D793d3b0279b5F0029180E83b6",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        ArrakisFeeTreasury: "0x2FF5D1da4985113F467BBBFF015e76ce8aB05F29",
      };
    case "polygon":
      return {
        Gelato: "0x7598e84B2E114AB62CAB288CE5f7d5f6bad35BbA",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        ArrakisFeeTreasury: "0xDEb4C33D5C3E7e32F55a9D6336FE06010E40E3AB",
      };
    case "optimism":
      return {
        Gelato: "0x01051113D81D7d6DA508462F2ad6d7fD96cF42Ef",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        ArrakisFeeTreasury: "0x8636600A864797Aa7ac8807A065C5d8BD9bA3Ccb",
      };
    case "goerli":
      return {
        Gelato: "0x683913B3A32ada4F8100458A3E1675425BdAa7DF",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        ArrakisFeeTreasury: "",
      };
    default:
      throw new Error(`No addresses for Network: ${network}`);
  }
};
