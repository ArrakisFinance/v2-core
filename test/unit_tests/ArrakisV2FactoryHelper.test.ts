import { expect } from "chai";
import hre = require("hardhat");
import {
  IEIP173Proxy,
  MockEIP173Implementation,
  ArrakisV2FactoryHelper,
} from "../../typechain";
const { ethers, deployments } = hre;

describe("Factory helper functions unit test", function () {
  this.timeout(0);

  let mock: MockEIP173Implementation;
  let proxy: IEIP173Proxy;
  let factoryHelper: ArrakisV2FactoryHelper;

  beforeEach("Setting up for Factory view function test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    await deployments.fixture();

    mock = (await ethers.getContract(
      "MockEIP173Implementation"
    )) as MockEIP173Implementation;

    proxy = (await ethers.getContract(
      "MockEIP173Implementation"
    )) as IEIP173Proxy;

    factoryHelper = (await ethers.getContract(
      "ArrakisV2FactoryHelper"
    )) as ArrakisV2FactoryHelper;
  });

  it("#0: Pool immutable check for managed proxy should be false", async () => {
    expect(await factoryHelper.isVaultImmutable(mock.address)).to.be.false;
  });

  it("#1: Pool immutable check for no managed proxy should be false", async () => {
    proxy.transferProxyAdmin(ethers.constants.AddressZero);
    expect(await factoryHelper.isVaultImmutable(mock.address)).to.be.true;
  });
});
