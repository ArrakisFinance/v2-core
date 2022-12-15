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
    hre.network.name === "optimism" ||
    hre.network.name === "arbitrum"
  ) {
    console.log(
      `Deploying ArrakisV2 to ${hre.network.name}. Hit ctrl + c to abort`
    );
    await sleep(10000);
  }

  const addresses = getAddresses(hre.network.name);
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy("ArrakisV2", {
    from: deployer,
    args: [addresses.UniswapV3Factory],
    libraries: {
      Pool: (await ethers.getContract("Pool")).address,
      Position: (await ethers.getContract("Position")).address,
      Underlying: (await ethers.getContract("Underlying")).address,
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
    hre.network.name === "optimism" ||
    hre.network.name === "arbitrum";
  return shouldSkip ? true : false;
};
func.tags = ["ArrakisV2"];
func.dependencies = ["Pool", "Position", "Underlying"];
