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
      `Deploying VaultV2Resolver to ${hre.network.name}. Hit ctrl + c to abort`
    );
    await sleep(10000);
  }

  const addresses = getAddresses(hre.network.name);
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy("VaultV2Resolver", {
    from: deployer,
    args: [
      addresses.UniswapV3Factory,
      (await ethers.getContract("VaultV2Helper")).address,
      addresses.SwapRouter,
    ],
    libraries: {
      Position: (await ethers.getContract("Position")).address,
      Underlying: (await ethers.getContract("Underlying")).address,
      UniswapV3Amounts: (await ethers.getContract("UniswapV3Amounts")).address,
      Twap: (await ethers.getContract("Twap")).address,
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
func.tags = ["VaultV2Resolver"];
func.dependencies = [
  "VaultV2Helper",
  "Position",
  "Twap",
  "Underlying",
  "Twap",
  "UniswapV3Amounts",
];
