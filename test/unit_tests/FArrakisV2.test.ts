import { expect } from "chai";
import hre = require("hardhat");
import { MockFArrakisV2 } from "../../typechain";
import { Addresses, getAddresses } from "../../src/addresses";
import { Signer, Contract } from "ethers";

const { ethers, deployments } = hre;

describe("Arrakis V2 smart contract internal functions unit test", function () {
  this.timeout(0);

  let user: Signer;
  let mockFArrakisV2: MockFArrakisV2;
  let addresses: Addresses;
  let poolContract: Contract;

  beforeEach("Setting up for Vault V2 functions unit test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    [user] = await ethers.getSigners();

    addresses = getAddresses(hre.network.name);

    await deployments.fixture();

    mockFArrakisV2 = (await ethers.getContract(
      "MockFArrakisV2"
    )) as MockFArrakisV2;

    poolContract = await ethers.getContractAt(
      [
        "function observe(uint32[] calldata secondsAgos) view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)",
      ],
      addresses.TestPool,
      user
    );
  });

  it("#0: Test Subtract Admin Fees", async () => {
    const rawFee0 = 100_000;
    const rawFee1 = 1_000_000;

    const managerFeeBPS = 1_000;
    const arrakisFeeBPS = 250;

    const result = await mockFArrakisV2.subtractAdminFees(
      rawFee0,
      rawFee1,
      managerFeeBPS,
      arrakisFeeBPS
    );

    expect(result.fee0.toNumber()).to.be.eq(
      87_500,
      "Admin fee 0 calculation not ok."
    );
    expect(result.fee1.toNumber()).to.be.eq(
      875_000,
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

  it("#4: get time weighted average price", async () => {
    const pool = addresses.TestPool;
    const twapDuration = 200; // 200 seconds

    // #region Expected

    const secondsAgo = [twapDuration, 0];

    const result = await poolContract.observe(secondsAgo);

    const expectedTick = result.tickCumulatives[1]
      .sub(result.tickCumulatives[0])
      .div(twapDuration);

    // #endregion Expected

    const tick = await mockFArrakisV2.getTwap(pool, twapDuration);

    expect(expectedTick).to.be.eq(tick);
  });

  it("#5: check Deviation, no deviation allowed should revert.", async () => {
    const pool = addresses.TestPool;
    const twapDuration = 200; // 200 seconds
    const maxDeviation = 0;

    await expect(
      mockFArrakisV2.checkDeviation(pool, twapDuration, maxDeviation)
    ).to.be.revertedWith("maxTwapDeviation");
  });

  it("#6: check Deviation", async () => {
    const pool = addresses.TestPool;
    const twapDuration = 200; // 200 seconds
    const maxDeviation = 1;

    await expect(
      mockFArrakisV2.checkDeviation(pool, twapDuration, maxDeviation)
    ).to.not.be.reverted;
  });
});
