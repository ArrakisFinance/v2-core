import hre from "hardhat";
import { getAddresses } from "../../src";

async function main() {
  const addresses = getAddresses(hre.network.name);

  await hre.run("verify:verify", {
    address: (await hre.ethers.getContract("ArrakisV2Resolver")).address,
    constructorArguments: [
      addresses.UniswapV3Factory,
      (await hre.ethers.getContract("ArrakisV2Helper")).address,
    ],
    // other args
    libraries: {
      Position: (await hre.ethers.getContract("Position")).address,
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
