import { ethers } from "hardhat";
import { ArrakisV2, ArrakisV2Resolver } from "../typechain";

// This script use standard burn method. Not optimized.
const vaultV2 = "0xe6F6f62a2e2802980dA493FfD14b4aaFE71972D0"; // vault v2 address
const amountToBurn = "227333571037108851"; // amount of Arrakis Vault token you want to burn.

async function main() {
  const [user] = await ethers.getSigners();
  const arrakisV2Resolver = (await ethers.getContract(
    "ArrakisV2Resolver"
  )) as ArrakisV2Resolver;

  const vault = (await ethers.getContractAt(
    "ArrakisV2",
    vaultV2,
    user
  )) as ArrakisV2;

  const token0Contract = new ethers.Contract(
    await vault.token0(),
    [
      "function decimals() external view returns (uint8)",
      "function balanceOf(address account) public view returns (uint256)",
      "function approve(address spender, uint256 amount) external returns (bool)",
      " function name() public view virtual override returns (string memory)",
    ],
    user
  );

  const token1Contract = new ethers.Contract(
    await vault.token1(),
    [
      "function decimals() external view returns (uint8)",
      "function balanceOf(address account) public view returns (uint256)",
      "function approve(address spender, uint256 amount) external returns (bool)",
      " function name() external view returns (string memory)",
    ],
    user
  );

  const userAddr = await user.getAddress();
  const token0Name = await token0Contract.name();
  const token1Name = await token1Contract.name();
  let balance0 = await token0Contract.balanceOf(userAddr);
  let balance1 = await token1Contract.balanceOf(userAddr);

  console.log(`Before Burn balance 0: ${balance0} ${token0Name}`);
  console.log(`Before Burn balance 1: ${balance1} ${token1Name}`);

  const result = await arrakisV2Resolver.standardBurnParams(
    amountToBurn,
    vaultV2
  );

  await vault.burn(result, amountToBurn, userAddr);

  balance0 = await token0Contract.balanceOf(userAddr);
  balance1 = await token1Contract.balanceOf(userAddr);

  console.log(`After Burn balance 0: ${balance0} ${token0Name}`);
  console.log(`After Burn balance 1: ${balance1} ${token1Name}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
