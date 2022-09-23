import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import {
  IUniswapV3Factory,
  IUniswapV3Pool,
  ArrakisV2,
  ArrakisV2Factory,
  ArrakisV2Resolver,
} from "../../typechain";
import { Addresses, getAddresses } from "../../src/addresses";
const { ethers, deployments } = hre;

describe("Factory function unit test", function () {
  this.timeout(0);

  let user: Signer;
  let user2: Signer;
  let owner: Signer;
  let userAddr: string;
  let ownerAddr: string;
  let arrakisV2Factory: ArrakisV2Factory;
  let uniswapV3Pool: IUniswapV3Pool;
  let arrakisV2Resolver: ArrakisV2Resolver;
  let addresses: Addresses;

  beforeEach("Setting up for Factory view function test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    addresses = getAddresses(hre.network.name);
    await deployments.fixture();

    [user, user2, owner] = await ethers.getSigners();
    userAddr = await user.getAddress();
    ownerAddr = await owner.getAddress();

    arrakisV2Factory = (await ethers.getContract(
      "ArrakisV2Factory"
    )) as ArrakisV2Factory;

    const uniswapV3Factory = (await ethers.getContractAt(
      "IUniswapV3Factory",
      addresses.UniswapV3Factory,
      user
    )) as IUniswapV3Factory;

    uniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      await uniswapV3Factory.getPool(addresses.USDC, addresses.WETH, 500),
      user
    )) as IUniswapV3Pool;

    arrakisV2Resolver = (await ethers.getContract(
      "ArrakisV2Resolver"
    )) as ArrakisV2Resolver;
  });

  it("#0: unit test create a vault v2", async () => {
    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    const lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    const upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    // For initialization.
    const res = await arrakisV2Resolver.getAmountsForLiquidity(
      slot0.tick,
      lowerTick,
      upperTick,
      ethers.utils.parseUnits("1", 18)
    );

    const tx = await arrakisV2Factory.deployVault(
      {
        feeTiers: [500],
        token0: addresses.USDC,
        token1: addresses.WETH,
        owner: userAddr,
        init0: res.amount0,
        init1: res.amount1,
        manager: userAddr,
        maxTwapDeviation: 100,
        twapDuration: 2000,
        maxSlippage: 100,
      },
      true
    );

    const rc = await tx.wait();
    const event = rc?.events?.find((event) => event.event === "VaultCreated");
    // eslint-disable-next-line no-unsafe-optional-chaining
    const result = event?.args;

    const vaultV2 = (await ethers.getContractAt(
      "ArrakisV2",
      result?.vault,
      user
    )) as ArrakisV2;

    expect(await vaultV2.name()).to.be.eq("Arrakis Vault V2 USDC/WETH");
  });

  it("#1: unit test get token name", async () => {
    expect(
      await arrakisV2Factory.getTokenName(addresses.USDC, addresses.WETH)
    ).to.be.eq("Arrakis Vault V2 USDC/WETH");
  });

  it("#3: unit test get deployer vault", async () => {
    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    const lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    const upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    // For initialization.
    const res = await arrakisV2Resolver.getAmountsForLiquidity(
      slot0.tick,
      lowerTick,
      upperTick,
      ethers.utils.parseUnits("1", 18)
    );

    await arrakisV2Factory.connect(user2).deployVault(
      {
        feeTiers: [500],
        token0: addresses.USDC,
        token1: addresses.WETH,
        owner: userAddr,
        init0: res.amount0,
        init1: res.amount1,
        manager: userAddr,
        maxTwapDeviation: 100,
        twapDuration: 2000,
        maxSlippage: 100,
      },
      true
    );

    expect(
      (await arrakisV2Factory.getVaultsByDeployer(await user2.getAddress()))
        .length
    ).to.be.eq(1);
  });

  it("#4: unit test get deployers", async () => {
    expect((await arrakisV2Factory.getDeployers()).length).to.be.eq(0);
  });

  it("#5: unit test get deployers", async () => {
    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    const lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    const upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    // For initialization.
    const res = await arrakisV2Resolver.getAmountsForLiquidity(
      slot0.tick,
      lowerTick,
      upperTick,
      ethers.utils.parseUnits("1", 18)
    );

    await arrakisV2Factory.connect(user).deployVault(
      {
        feeTiers: [500],
        token0: addresses.USDC,
        token1: addresses.WETH,
        owner: userAddr,
        init0: res.amount0,
        init1: res.amount1,
        manager: userAddr,
        maxTwapDeviation: 100,
        twapDuration: 2000,
        maxSlippage: 100,
      },
      true
    );

    expect((await arrakisV2Factory.getDeployers()).length).to.be.eq(1);
  });

  it("#6: unit test get num Vaults", async () => {
    expect(await arrakisV2Factory.numVaults()).to.be.eq(0);
  });

  it("#7: unit test get num Vaults", async () => {
    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    const lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    const upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    // For initialization.
    const res = await arrakisV2Resolver.getAmountsForLiquidity(
      slot0.tick,
      lowerTick,
      upperTick,
      ethers.utils.parseUnits("1", 18)
    );

    await arrakisV2Factory.connect(user).deployVault(
      {
        feeTiers: [500],
        token0: addresses.USDC,
        token1: addresses.WETH,
        owner: userAddr,
        init0: res.amount0,
        init1: res.amount1,
        manager: userAddr,
        maxTwapDeviation: 100,
        twapDuration: 2000,
        maxSlippage: 100,
      },
      true
    );

    expect(await arrakisV2Factory.numVaults()).to.be.eq(1);
  });

  it("#8: unit test get num Vaults by Deployer", async () => {
    expect(await arrakisV2Factory.numVaultsByDeployer(userAddr)).to.be.eq(0);
  });

  it("#9: unit test get num Vaults by Deployer", async () => {
    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    const lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    const upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    // For initialization.
    const res = await arrakisV2Resolver.getAmountsForLiquidity(
      slot0.tick,
      lowerTick,
      upperTick,
      ethers.utils.parseUnits("1", 18)
    );

    await arrakisV2Factory.connect(owner).deployVault(
      {
        feeTiers: [500],
        token0: addresses.USDC,
        token1: addresses.WETH,
        owner: userAddr,
        init0: res.amount0,
        init1: res.amount1,
        manager: userAddr,
        maxTwapDeviation: 100,
        twapDuration: 2000,
        maxSlippage: 100,
      },
      false
    );

    expect(await arrakisV2Factory.numVaultsByDeployer(ownerAddr)).to.be.eq(1);
  });

  it("#10: unit test get num of deployers", async () => {
    expect(await arrakisV2Factory.numDeployers()).to.be.eq(0);
  });

  it("#11: unit test get vaults by deployers", async () => {
    expect(
      (await arrakisV2Factory.getVaultsByDeployer(userAddr)).length
    ).to.be.eq(0);
  });

  it("#12: unit test get vaults by deployers", async () => {
    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    const lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    const upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    // For initialization.
    const res = await arrakisV2Resolver.getAmountsForLiquidity(
      slot0.tick,
      lowerTick,
      upperTick,
      ethers.utils.parseUnits("1", 18)
    );

    await arrakisV2Factory.connect(user).deployVault(
      {
        feeTiers: [500],
        token0: addresses.USDC,
        token1: addresses.WETH,
        owner: userAddr,
        init0: res.amount0,
        init1: res.amount1,
        manager: userAddr,
        maxTwapDeviation: 100,
        twapDuration: 2000,
        maxSlippage: 100,
      },
      false
    );

    expect(
      (await arrakisV2Factory.getVaultsByDeployer(userAddr)).length
    ).to.be.eq(1);
  });
});
