import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import { ArrakisV2Beacon } from "../../typechain";
const { ethers, deployments } = hre;

describe("Factory function unit test", function () {
  this.timeout(0);

  let user: Signer;
  let user2: Signer;
  let arrakisV2Beacon: ArrakisV2Beacon;

  beforeEach("Setting up for Factory view function test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    await deployments.fixture();

    [user, user2] = await ethers.getSigners();

    arrakisV2Beacon = (await ethers.getContract(
      "ArrakisV2Beacon"
    )) as ArrakisV2Beacon;
  });

  it("#13: unit test set vault implementation should ", async () => {
    expect(await arrakisV2Beacon.implementation()).to.not.eq(
      ethers.constants.AddressZero
    );

    await expect(
      arrakisV2Beacon.connect(user).upgradeTo(await user2.getAddress())
    ).to.be.reverted; // because is not a contract.

    await expect(
      arrakisV2Beacon
        .connect(user)
        .upgradeTo((await ethers.getContract("ArrakisV2Factory")).address)
    ).to.not.be.reverted;
  });

  it("#14: unit test set pool implementation", async () => {
    await expect(
      arrakisV2Beacon.connect(user2).upgradeTo(ethers.constants.AddressZero)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
