import hre from "hardhat";
import { getAddresses, Addresses } from "../../src/addresses";

async function main() {
  const addresses: Addresses = getAddresses(hre.network.name);

  await hre.run("verify:verify", {
    address: (await hre.ethers.getContract("ArrakisV2Resolver")).address,
    constructorArguments: [addresses.UniswapV3Factory],
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
