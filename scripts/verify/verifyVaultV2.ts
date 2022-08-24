import hre from "hardhat";
import { getAddresses } from "../../src/addresses";

async function main() {
  const { deployer } = await hre.getNamedAccounts();
  const addresses = getAddresses(hre.network.name);

  await hre.run("verify:verify", {
    address: (await hre.ethers.getContract("ArrakisV2")).address,
    constructorArguments: [addresses.UniswapV3Factory, deployer],
    // other args
    libraries: {
      Twap: (await hre.ethers.getContract("Twap")).address,
      Underlying: (await hre.ethers.getContract("Underlying")).address,
      UniswapV3Amounts: (
        await hre.ethers.getContract("UniswapV3Amounts")
      ).address,
    },
  });
}

main()
  .then(() => process.exit(0))
  .catch(async (error) => {
    console.error(error);
    process.exit(1);
  });
