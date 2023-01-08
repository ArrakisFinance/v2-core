import hre from "hardhat";
import { getAddresses } from "../../src";

async function main() {
  const addresses = getAddresses(hre.network.name);

  await hre.run("verify:verify", {
    address: (await hre.ethers.getContract("ArrakisV2")).address,
    constructorArguments: [addresses.UniswapV3Factory],
    // other args
    libraries: {
      Underlying: (await hre.ethers.getContract("Underlying")).address,
      Pool: (await hre.ethers.getContract("Pool")).address,
      Twap: (await hre.ethers.getContract("Twap")).address,
      Position: (await hre.ethers.getContract("Position")).address,
    },
  });
}

main()
  .then(() => process.exit(0))
  .catch(async (error) => {
    console.error(error);
    process.exit(1);
  });
