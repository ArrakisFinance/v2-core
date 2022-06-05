import { deployments, getNamedAccounts, ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getAddresses } from "../src/addresses";
import { sleep } from "../src/utils";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  if (
    hre.network.name === "mainnet" ||
    hre.network.name === "polygon" ||
    hre.network.name === "goerli" ||
    hre.network.name === "optimism"
  ) {
    console.log(
      `Deploying VaultV2 to ${hre.network.name}. Hit ctrl + c to abort`
    );
    await sleep(10000);
  }

  const addresses = getAddresses(hre.network.name);
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy("VaultV2", {
    from: deployer,
    args: [addresses.UniswapV3Factory, deployer],
    libraries: {
      Pool: (await ethers.getContract("Pool")).address,
      Position: (await ethers.getContract("Position")).address,
      Twap: (await ethers.getContract("Twap")).address,
      Underlying: (await ethers.getContract("Underlying")).address,
      UniswapV3Amounts: (await ethers.getContract("UniswapV3Amounts")).address,
    },
    log: hre.network.name != "hardhat" ? true : false,
    gasLimit: 30000000,
  });
};

export default func;

func.skip = async (hre: HardhatRuntimeEnvironment) => {
  const shouldSkip =
    hre.network.name === "mainnet" ||
    hre.network.name === "polygon" ||
    hre.network.name === "goerli" ||
    hre.network.name === "optimism";
  return shouldSkip ? true : false;
};
func.tags = ["VaultV2"];
func.dependencies = [
  "Pool",
  "Position",
  "Twap",
  "Underlying",
  "UniswapV3Amounts",
];
