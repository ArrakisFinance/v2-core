import hre from "hardhat";
import { getAddresses } from "../../src/addresses";

async function main() {
  const addresses = getAddresses(hre.network.name);

  await hre.run("verify:verify", {
    address: (await hre.ethers.getContract("VaultV2Resolver")).address,
    constructorArguments: [
      addresses.UniswapV3Factory,
      (await hre.ethers.getContract("VaultV2Helper")).address,
      addresses.SwapRouter,
    ],
    // other args
    libraries: {
      Position: (await hre.ethers.getContract("Position")).address,
      UniswapV3Amounts: (
        await hre.ethers.getContract("UniswapV3Amounts")
      ).address,
      Underlying: (await hre.ethers.getContract("Underlying")).address,
    },
  });
}

main()
  .then(() => process.exit(0))
  .catch(async (error) => {
    console.error(error);
    process.exit(1);
  });
