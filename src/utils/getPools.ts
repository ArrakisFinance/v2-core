import { ethers, BigNumber } from "ethers";

export const getPools = async (
  provider: ethers.providers.Provider,
  vault: string
): Promise<string[]> => {
  // Position 211 for _pools.
  const poolsIndex = 211;
  const result: string[] = [];
  const poolsLength = ethers.utils.defaultAbiCoder.decode(
    ["uint256"],
    await provider.getStorageAt(
      vault,
      ethers.utils.hexZeroPad(BigNumber.from(poolsIndex).toHexString(), 32)
    )
  );
  for (let i = 0; i < poolsLength[0].toNumber(); i++) {
    result[i] = ethers.utils.defaultAbiCoder.decode(
      ["address"],
      await provider.getStorageAt(
        vault,
        BigNumber.from(
          ethers.utils.keccak256(
            ethers.utils.hexZeroPad(
              BigNumber.from(poolsIndex).toHexString(),
              32
            )
          )
        ).add(i)
      )
    )[0];
  }
  return result;
};
