import { expect } from "chai";
import hre = require("hardhat");
import { MockFArrakisV2 } from "../../typechain";

const { ethers, deployments } = hre;

describe("Arrakis V2 smart contract internal functions unit test", function () {
  this.timeout(0);

  let mockFArrakisV2: MockFArrakisV2;

  beforeEach("Setting up for Vault V2 functions unit test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    await deployments.fixture();

    mockFArrakisV2 = (await ethers.getContract(
      "MockFArrakisV2"
    )) as MockFArrakisV2;
  });

  it("#0: Test Subtract Admin Fees", async () => {
    const rawFee0 = 100_000;
    const rawFee1 = 1_000_000;

    const managerFeeBPS = 1_000;

    const result = await mockFArrakisV2.subtractAdminFees(
      rawFee0,
      rawFee1,
      managerFeeBPS
    );

    expect(result.fee0.toNumber()).to.be.eq(
      90_000,
      "Admin fee 0 calculation not ok."
    );
    expect(result.fee1.toNumber()).to.be.eq(
      900_000,
      "Admin fee 0 calculation not ok."
    );
  });

  it("#1: Test Compute Mint Amounts, when current1 is Zero", async () => {
    const current0 = ethers.utils.parseUnits("1", 6);
    const current1 = ethers.constants.Zero;

    const totalSupply = ethers.utils.parseUnits("1", 9);
    const amount0Max = ethers.utils.parseUnits("1", 3);
    const amount1Max = ethers.constants.Zero;

    const result = await mockFArrakisV2.computeMintAmounts(
      current0,
      current1,
      totalSupply,
      amount0Max,
      amount1Max
    );

    const expectedMintAmount = amount0Max.mul(totalSupply).div(current0);
    const expectedAmount0 = expectedMintAmount.mul(current0).div(totalSupply);

    expect(result.mintAmount).to.be.equal(expectedMintAmount);
    expect(result.amount0).to.be.equal(expectedAmount0);
    expect(result.amount1).to.be.equal(0);
  });

  it("#2: Test Compute Mint Amounts, when current0 is Zero", async () => {
    const current1 = ethers.utils.parseUnits("1", 6);
    const current0 = ethers.constants.Zero;

    const totalSupply = ethers.utils.parseUnits("1", 9);
    const amount1Max = ethers.utils.parseUnits("1", 3);
    const amount0Max = ethers.constants.Zero;

    const result = await mockFArrakisV2.computeMintAmounts(
      current0,
      current1,
      totalSupply,
      amount0Max,
      amount1Max
    );

    const expectedMintAmount = amount1Max.mul(totalSupply).div(current1);
    const expectedAmount1 = expectedMintAmount.mul(current1).div(totalSupply);

    expect(result.mintAmount).to.be.equal(expectedMintAmount);
    expect(result.amount1).to.be.equal(expectedAmount1);
    expect(result.amount0).to.be.equal(0);
  });

  it("#3: Test Compute Mint Amounts", async () => {
    const current1 = ethers.utils.parseUnits("1", 6);
    const current0 = ethers.utils.parseUnits("3", 6);

    const totalSupply = ethers.utils.parseUnits("1", 9);
    const amount1Max = ethers.utils.parseUnits("1", 3);
    const amount0Max = ethers.utils.parseUnits("3", 3);

    const result = await mockFArrakisV2.computeMintAmounts(
      current0,
      current1,
      totalSupply,
      amount0Max,
      amount1Max
    );

    const expectedMintAmount = amount1Max.mul(totalSupply).div(current1);
    const expectedAmount1 = expectedMintAmount.mul(current1).div(totalSupply);
    const expectedAmount0 = expectedMintAmount.mul(current0).div(totalSupply);

    expect(result.mintAmount).to.be.equal(expectedMintAmount);
    expect(result.amount1).to.be.equal(expectedAmount1);
    expect(result.amount0).to.be.equal(expectedAmount0);
  });
  it("#4: Test mulDiv edge cases", async () => {
    const oneEth = ethers.utils.parseEther("1");
    const result1 = await mockFArrakisV2.checkMulDiv(
      oneEth.mul(10),
      oneEth.sub(1),
      oneEth
    );
    expect(result1).to.be.lt(oneEth.mul(10));
    expect(result1).to.be.gt(oneEth.mul(9));

    const fivek = ethers.BigNumber.from("5000");
    const result2 = await mockFArrakisV2.checkMulDiv(
      fivek,
      oneEth.sub(1),
      oneEth
    );
    expect(result2).to.be.lt(fivek);
    expect(result2).to.be.eq(ethers.BigNumber.from("4999"));

    const result3 = await mockFArrakisV2.checkMulDiv(
      ethers.constants.One,
      oneEth.mul(100).sub(1),
      oneEth.mul(100)
    );
    expect(result3).to.be.eq(ethers.constants.Zero);
  });
});
