import { ethers, BigNumber } from "ethers";

export const getRouters = async (
  provider: ethers.providers.Provider,
  vault: string
): Promise<string[]> => {
  // Position 213 for _routers.
  const routersIndex = 213;
  const result: string[] = [];
  const routersLength = ethers.utils.defaultAbiCoder.decode(
    ["uint256"],
    await provider.getStorageAt(
      vault,
      ethers.utils.hexZeroPad(BigNumber.from(routersIndex).toHexString(), 32)
    )
  );
  for (let i = 0; i < routersLength[0].toNumber(); i++) {
    result[i] = ethers.utils.defaultAbiCoder.decode(
      ["address"],
      await provider.getStorageAt(
        vault,
        BigNumber.from(
          ethers.utils.keccak256(
            ethers.utils.hexZeroPad(
              BigNumber.from(routersIndex).toHexString(),
              32
            )
          )
        ).add(i)
      )
    )[0];
  }
  return result;
};
