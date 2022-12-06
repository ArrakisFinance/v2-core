import hre from "hardhat";

async function main() {
  await hre.run("verify:verify", {
    address: (await hre.ethers.getContract("Underlying")).address,
    // other args
    libraries: {
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
