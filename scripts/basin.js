const {
  AQUIFER,
  CONSTANT_PRODUCT_2,
  BEANSTALK_PUMP,
  WELL_IMPLEMENTATION,
  WELL_IMPLEMENTATION_UPGRADEABLE,
  STABLE_2
} = require("../test/hardhat/utils/constants");

const { impersonateSigner } = require("../utils");
const { getWellContractAt, getWellContractFactory } = require("../utils/well");

async function deployBasin(mock = true, verbose = false) {
  let c = {};

  if (verbose) console.log("Deploying Basin...");

  c.aquifer = await deployAquifer(verbose);
  c.constantProduct2 = await deployConstantProduct2(verbose);
  c.stable2 = await deployStable2(verbose);

  if (mock) {
    c.multiFlowPump = await deployMockPump(BEANSTALK_PUMP, verbose);
  } else {
    c.multiFlowPump = await deployMultiFlowPump(BEANSTALK_PUMP, verbose);
  }

  c = await deployWellImplementation(verbose);
  c.upgradeableWellImplementation = await deployUpgradeableWellImplementation(verbose);
  return c;
}

async function deployAquifer(verbose = false) {
  let Aquifer = await getWellContractFactory("Aquifer");
  let aquifer = await Aquifer.deploy();
  await aquifer.deployed();
  const bytecode = await ethers.provider.getCode(aquifer.address);
  await network.provider.send("hardhat_setCode", [AQUIFER, bytecode]);
  if (verbose) {
    console.log("Deploying Aquifer...");
    console.log("Aquifer deployed at:", aquifer.address);
  }
  return await ethers.getContractAt("IAquifer", AQUIFER);
}

async function deployConstantProduct2(verbose = false) {
  let ConstantProduct2 = await getWellContractFactory("ConstantProduct2");
  let constantProduct2 = await ConstantProduct2.deploy();
  await constantProduct2.deployed();
  const bytecode = await ethers.provider.getCode(constantProduct2.address);
  await network.provider.send("hardhat_setCode", [CONSTANT_PRODUCT_2, bytecode]);
  if (verbose) {
    console.log("Deploying ConstantProduct2...");
    console.log("ConstantProduct2 deployed at:", constantProduct2.address);
  }
  return await ethers.getContractAt("IMultiFlowPumpWellFunction", CONSTANT_PRODUCT_2);
}

async function deployMockPump(address = BEANSTALK_PUMP, verbose = false) {
  pump = await (await ethers.getContractFactory("MockPump")).deploy();
  await pump.deployed();
  await network.provider.send("hardhat_setCode", [
    address,
    await ethers.provider.getCode(pump.address)
  ]);
  if (verbose) console.log("deployed Mock Pump at:", address);
  return await ethers.getContractAt("MockPump", address);
}

async function deployMultiFlowPump(address = BEANSTALK_PUMP, verbose) {
  pump = await (await getWellContractFactory("MultiFlowPump")).deploy();
  await pump.deployed();

  await network.provider.send("hardhat_setCode", [
    address,
    await ethers.provider.getCode(pump.address)
  ]);

  if (verbose) console.log("deployed Mock Pump at:", address);
  return await getWellContractAt("MultiFlowPump", BEANSTALK_PUMP);
}

async function deployWellImplementation(verbose = true) {
  const wellImplementation = await (await getWellContractFactory("Well")).deploy();
  await wellImplementation.deployed();
  await network.provider.send("hardhat_setCode", [
    WELL_IMPLEMENTATION,
    await ethers.provider.getCode(wellImplementation.address)
  ]);
  if (verbose) console.log("Well Implementation Deployed at", wellImplementation.address);
  return wellImplementation;
}

async function deployUpgradeableWellImplementation(verbose = true) {
  const wellImplementation = await (await getWellContractFactory("WellUpgradeable")).deploy();
  await wellImplementation.deployed();
  await network.provider.send("hardhat_setCode", [
    WELL_IMPLEMENTATION_UPGRADEABLE,
    await ethers.provider.getCode(wellImplementation.address)
  ]);
  if (verbose)
    console.log("Well Upgradeable Implementation Deployed at", wellImplementation.address);
  return wellImplementation;
}

async function deployStable2(verbose = true) {
  const lookupTable = await (await getWellContractFactory("Stable2LUT1")).deploy();
  await lookupTable.deployed();
  const stable2 = await (await getWellContractFactory("Stable2")).deploy(lookupTable.address);
  await stable2.deployed();
  await network.provider.send("hardhat_setCode", [
    STABLE_2,
    await ethers.provider.getCode(stable2.address)
  ]);
  if (verbose) console.log("Stable2 Deployed at", stable2.address);
  return stable2;
}

async function getAccount(accounts, key, mockAddress) {
  if (accounts == undefined) {
    return await impersonateSigner(mockAddress, true);
  }
  return accounts[key];
}

exports.deployBasin = deployBasin;
exports.getAccount = getAccount;
exports.deployAquifer = deployAquifer;
exports.deployWellImplementation = deployWellImplementation;
