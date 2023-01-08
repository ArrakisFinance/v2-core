import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import { ArrakisV2, IUniswapV3Factory } from "../../typechain";
import { Addresses, getAddresses } from "../../src";
const { ethers, deployments } = hre;

describe("ArrakisV2 functions unit test", function () {
  this.timeout(0);

  let arrakisTreasury: Signer;
  let arrakisTreasuryAddr: string;
  let newManager: Signer;
  let newManagerAddr: string;
  let manager: Signer;
  let managerAddr: string;
  let arrakisV2: ArrakisV2;
  let addresses: Addresses;

  before("Setting up for ArrakisV2 function test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    await deployments.fixture();

    addresses = getAddresses(hre.network.name);

    [newManager, manager, , arrakisTreasury] = await ethers.getSigners();

    arrakisTreasuryAddr = await arrakisTreasury.getAddress();
    newManagerAddr = await newManager.getAddress();
    managerAddr = await manager.getAddress();

    arrakisV2 = await ethers.getContract("ArrakisV2", arrakisTreasury);
  });

  it("#0: Initialize", async () => {
    await arrakisV2.initialize("Name", "Symbol", {
      feeTiers: [500],
      token0: addresses.USDC,
      token1: addresses.WETH,
      owner: arrakisTreasuryAddr,
      init0: ethers.constants.One,
      init1: ethers.constants.Zero,
      manager: managerAddr,
      routers: [addresses.SwapRouter],
      burnBuffer: 1000,
      maxTwapDeviation: 100,
      twapDuration: 100,
    });

    expect(await arrakisV2.token0()).to.be.eq(addresses.USDC);
    expect(await arrakisV2.token1()).to.be.eq(addresses.WETH);

    expect(await arrakisV2.owner()).to.be.eq(arrakisTreasuryAddr);
    expect(await arrakisV2.init0()).to.be.eq(ethers.constants.One);
    expect(await arrakisV2.init1()).to.be.eq(ethers.constants.Zero);
    expect(await arrakisV2.manager()).to.be.eq(managerAddr);
  });

  it("#1: set inits, should revert if caller is not restricted minter or owner", async () => {
    await expect(
      arrakisV2
        .connect(manager)
        .setInits(ethers.constants.Zero, ethers.constants.One)
    ).to.be.revertedWith("R");
  });
  it("#2: set inits, should revert if init0 and init1 equal to zero", async () => {
    await expect(
      arrakisV2.setInits(ethers.constants.Zero, ethers.constants.Zero)
    ).to.be.revertedWith("I");
  });

  it("#3: set inits as Owner", async () => {
    expect(await arrakisV2.init0()).to.be.eq(ethers.constants.One);
    expect(await arrakisV2.init1()).to.be.eq(ethers.constants.Zero);

    await expect(
      arrakisV2.setInits(ethers.constants.Zero, ethers.constants.One)
    ).to.not.be.reverted;

    expect(await arrakisV2.init0()).to.be.eq(ethers.constants.Zero);
    expect(await arrakisV2.init1()).to.be.eq(ethers.constants.One);
  });

  it("#4: set inits as restricted minter", async () => {
    await arrakisV2.setRestrictedMint(managerAddr);

    expect(await arrakisV2.init0()).to.be.eq(ethers.constants.Zero);
    expect(await arrakisV2.init1()).to.be.eq(ethers.constants.One);

    await expect(
      arrakisV2
        .connect(manager)
        .setInits(ethers.constants.Zero, ethers.constants.Two)
    ).to.not.be.reverted;

    expect(await arrakisV2.init0()).to.be.eq(ethers.constants.Zero);
    expect(await arrakisV2.init1()).to.be.eq(ethers.constants.Two);
  });

  it("#5: add pool, should revert if already added", async () => {
    await expect(arrakisV2.addPools([500])).to.be.revertedWith("P");
  });

  it("#6: add pool, should revert if already added", async () => {
    await expect(arrakisV2.addPools([5000])).to.be.revertedWith("ZA");
  });
  it("#7: add pool, should revert if called by other account than owner", async () => {
    await expect(arrakisV2.connect(manager).addPools([100])).to.be.revertedWith(
      "Ownable: caller is not the owner"
    );
  });

  it("#8: add pool", async () => {
    await expect(arrakisV2.addPools([3000])).to.not.be.reverted;
  });

  it("#9: remove pool, should revert if called by other account than owner", async () => {
    await expect(
      arrakisV2.connect(manager).removePools([ethers.constants.AddressZero])
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  //   it("#10: remove pool, should revert if owner try to remove address zero", async () => {
  //     await expect(
  //       arrakisV2.removePools([ethers.constants.AddressZero])
  //     ).to.be.revertedWith("Z");
  //   });
  it("#11: remove pool, should revert if owner try to remove not a whitelisted pool", async () => {
    await expect(arrakisV2.removePools([arrakisV2.address])).to.be.revertedWith(
      "NP"
    );
  });

  it("#12: remove pool", async () => {
    const uniswapV3Factory = (await ethers.getContractAt(
      "IUniswapV3Factory",
      addresses.UniswapV3Factory,
      arrakisTreasury
    )) as IUniswapV3Factory;

    const pool = uniswapV3Factory.getPool(
      await arrakisV2.token0(),
      await arrakisV2.token1(),
      3000
    );

    await expect(arrakisV2.removePools([pool])).to.not.be.reverted;
  });

  it("#13: set manager, should revert if called by other account than owner", async () => {
    await expect(
      arrakisV2.connect(manager).setManager(managerAddr)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("#14: set manager", async () => {
    expect(await arrakisV2.manager()).to.be.eq(managerAddr);
    await expect(arrakisV2.setManager(newManagerAddr)).to.not.be.reverted;
    expect(await arrakisV2.manager()).to.be.eq(newManagerAddr);
  });

  it("#15: set restricted minter, should revert if called by other account than owner", async () => {
    await expect(
      arrakisV2.connect(manager).setRestrictedMint(managerAddr)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("#16: set restricted minter", async () => {
    expect(await arrakisV2.restrictedMint()).to.be.eq(managerAddr);

    await expect(arrakisV2.setRestrictedMint(newManagerAddr)).to.not.be
      .reverted;

    expect(await arrakisV2.restrictedMint()).to.be.eq(newManagerAddr);
  });
});
