import { ethers } from "hardhat";
import { VaultV2, VaultV2Resolver } from "../typechain";
import { BigNumber } from "ethers";

const vaultV2 = ""; // vault V2 address
const amount0 = 0; // max amount of token0.
const amount1 = 0; // max amount of token1.

async function main() {
  const [user] = await ethers.getSigners();

  const vaultV2Resolver = (await ethers.getContract(
    "VaultV2Resolver"
  )) as VaultV2Resolver;

  const result = await vaultV2Resolver.getMintAmounts(
    vaultV2,
    amount0,
    amount1
  );

  const vault = (await ethers.getContractAt(
    "VaultV2",
    vaultV2,
    user
  )) as VaultV2;

  const token0Contract = new ethers.Contract(
    await vault.token0(),
    [
      "function decimals() external view returns (uint8)",
      "function balanceOf(address account) public view returns (uint256)",
      "function approve(address spender, uint256 amount) external returns (bool)",
    ],
    user
  );

  const token1Contract = new ethers.Contract(
    await vault.token1(),
    [
      "function decimals() external view returns (uint8)",
      "function balanceOf(address account) public view returns (uint256)",
      "function approve(address spender, uint256 amount) external returns (bool)",
    ],
    user
  );

  const userAddr = await user.getAddress();
  const token0Balance: BigNumber = await token0Contract.balanceOf(userAddr);
  const token1Balance: BigNumber = await token1Contract.balanceOf(userAddr);

  if (!(token0Balance.gte(result.amount0) && token1Balance.gte(result.amount1)))
    throw new Error("Balance not enough");

  await token0Contract.approv(vault.address, result.amount0);
  await token1Contract.approv(vault.address, result.amount1);

  await vault.mint(result.mintAmount, userAddr);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
