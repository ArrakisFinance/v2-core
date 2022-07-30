import { ethers } from "hardhat";
import { VaultV2, VaultV2Resolver } from "../typechain";
import { RangeWeightStruct } from "../typechain/contracts/VaultV2Resolver";

//standard mint.
const rangeWeights: RangeWeightStruct[] = [
  {
    range: { lowerTick: "-81120", upperTick: "-76000", feeTier: 500 },
    weight: "5000",
  },
]; // list of rangeWeigth.
const vaultV2 = "0xe6F6f62a2e2802980dA493FfD14b4aaFE71972D0";

async function main() {
  const [user] = await ethers.getSigners();
  const vaultV2Resolver = (await ethers.getContract(
    "VaultV2Resolver"
  )) as VaultV2Resolver;

  const vault = (await ethers.getContractAt(
    "VaultV2",
    vaultV2,
    user
  )) as VaultV2;

  const result = await vaultV2Resolver.standardRebalance(rangeWeights, vaultV2);

  await vault.rebalance(
    [{ lowerTick: "-81120", upperTick: "-76000", feeTier: 500 }],
    result,
    []
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
