import { HardhatUserConfig, task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getAddresses } from "../src/addresses";
import { ArrakisV2 as ArrakisV2Type } from "../typechain/contracts/ArrakisV2";
import { IERC20 } from "../typechain/@openzeppelin/contracts/token/ERC20";
import { libraries } from "../typechain/contracts";
import { BigNumber, Contract } from "ethers";

async function deployArtifact(
  contractName: any,
  factoryOpts: any,
  hre: HardhatRuntimeEnvironment,
  shouldVerify: boolean = true
): Promise<string> {
  const hardhat = await import("hardhat");

  // deploy artifact
  console.log("Deploying: ", contractName);
  const Artifact = await hardhat.ethers.getContractFactory(
    contractName,
    factoryOpts
  );
  const aftifact = await Artifact.deploy();
  const artifactAddress: string = aftifact.address;

  // verify aftifact

  if (shouldVerify) {
    console.log("Verifying: ", contractName);
    await hardhat.run("verify", { address: artifactAddress });
  }
  console.log(contractName, " deployed at: ", artifactAddress);
  console.log("");

  return artifactAddress;
}

async function approveToken(
  tokenAddr: string,
  toAddr: string,
  hre: HardhatRuntimeEnvironment
) {
  const [signer] = await hre.ethers.getSigners();
  let token = new hre.ethers.Contract(
    tokenAddr,
    [
      "function decimals() external view returns (uint8)",
      "function balanceOf(address account) public view returns (uint256)",
      "function approve(address spender, uint256 amount) external returns (bool)",
      "function transfer(address to, uint256 amount) external returns (bool)",
    ],
    signer
  );
  await token.approve(toAddr, hre.ethers.constants.MaxUint256);
}

export default function () {
  task("deployPool", "Deploy ArrakisV2 pool").setAction(
    async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
      const addresses = getAddresses(hre.network.name);

      const [signer] = await hre.ethers.getSigners();
      const tokenName = "Vault Test Token";
      const tokenSymbol = "VTT";
      const fees = [500];
      const token0 = addresses.WETH;
      const token1 = addresses.USDC;
      const ownerAddr = addresses.OwnerAddr;
      const init0 = "1000000";
      const init1 = "1000";
      const managerAddr = addresses.ManagerAddr;
      const routers = [addresses.SwapRouter];
      const factoryAddr = addresses.UniswapV3Factory;
      const shouldVerify: boolean = false;

      // deploying libraries
      const poolAddress = await deployArtifact("Pool", {}, hre, shouldVerify);
      const positionAddress = await deployArtifact(
        "Position",
        {},
        hre,
        shouldVerify
      );
      const underlyingAddress = await deployArtifact(
        "Underlying",
        { libraries: { Position: positionAddress } },
        hre,
        shouldVerify
      );
      const investAddress = await deployArtifact(
        "Invest",
        {
          libraries: {
            Pool: poolAddress,
            Position: positionAddress,
            Underlying: underlyingAddress,
          },
        },
        hre,
        shouldVerify
      );

      // deploying proxy
      console.log("Deploying ArrakisV2");
      const ArrakisV2 = await hre.ethers.getContractFactory("ArrakisV2", {
        libraries: { Invest: investAddress },
      });
      const arrakisV2 = (await hre.upgrades.deployProxy(
        ArrakisV2,
        [
          tokenName,
          tokenSymbol,
          [
            fees,
            token0,
            token1,
            ownerAddr,
            init0,
            init1,
            managerAddr,
            routers,
            factoryAddr,
          ],
        ],
        {
          constructorArgs: [],
          kind: "uups",
          unsafeAllow: ["external-library-linking"],
        }
      )) as ArrakisV2Type;
      const arrakisV2Address: string = await arrakisV2.address;
      if (shouldVerify) {
        console.log("Verifying: ArrakisV2");
        await hre.run("verify", { address: arrakisV2Address });
      }
      console.log("ArrakisV2 deployed at: ", arrakisV2Address);

      await approveToken(token0, arrakisV2Address, hre);
      await approveToken(token1, arrakisV2Address, hre);
      arrakisV2.mint(hre.ethers.utils.parseEther("1"), signer.address);
      console.log("\nminted 1 token");
    }
  );
}
