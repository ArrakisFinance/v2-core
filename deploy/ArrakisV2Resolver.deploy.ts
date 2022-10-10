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
      `Deploying ArrakisV2Resolver to ${hre.network.name}. Hit ctrl + c to abort`
    );
    await sleep(10000);
  }

  const addresses = getAddresses(hre.network.name);
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy("ArrakisV2Resolver", {
    from: deployer,
    args: [
      addresses.UniswapV3Factory,
      (await ethers.getContract("ArrakisV2Helper")).address,
      addresses.SwapRouter,
    ],
    libraries: {
      Position: (await ethers.getContract("Position")).address,
      Underlying: (await ethers.getContract("Underlying")).address,
      UniswapV3Amounts: (await ethers.getContract("UniswapV3Amounts")).address,
      Manager: (await ethers.getContract("Manager")).address,
    },
    log: hre.network.name != "hardhat" ? true : false,
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
func.tags = ["ArrakisV2Resolver"];
func.dependencies = [
  "ArrakisV2Helper",
  "Position",
  "Underlying",
  "UniswapV3Amounts",
];
