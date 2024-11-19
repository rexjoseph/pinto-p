const { expect } = require("chai");
const { deploy } = require("../../scripts/deploy.js");
const { BEAN, BEAN_ETH_WELL, WETH, BEAN_WSTETH_WELL } = require("./utils/constants.js");
const { to6, to18 } = require("./utils/helpers.js");
const { takeSnapshot, revertToSnapshot } = require("./utils/snapshot");
const { deployMockBeanWell } = require("../../utils/well.js");
const { advanceTime } = require("../../utils/helpers.js");
const { setEthUsdChainlinkPrice } = require("../../utils/oracle.js");
const { getAllBeanstalkContracts } = require("../../utils/contracts");

let user, owner;

async function setToSecondsAfterHour(seconds = 0) {
  const lastTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
  const hourTimestamp = parseInt(lastTimestamp / 3600 + 1) * 3600 + seconds;
  await network.provider.send("evm_setNextBlockTimestamp", [hourTimestamp]);
}

describe("Season", function () {
  before(async function () {
    [owner, user, user2] = await ethers.getSigners();
    const contracts = await deploy((verbose = false), (mock = true), (reset = true));
    this.diamond = contracts.beanstalkDiamond;
    // `beanstalk` contains all functions that the regular beanstalk has.
    // `mockBeanstalk` has functions that are only available in the mockFacets.
    [beanstalk, mockBeanstalk] = await getAllBeanstalkContracts(this.diamond.address);

    bean = await ethers.getContractAt("MockToken", BEAN);
    // add wells
    [this.beanEthWell, this.beanEthWellFunction, this.pump] = await deployMockBeanWell(
      BEAN_ETH_WELL,
      WETH
    );
    [this.beanWstethWell, this.beanEthWellFunction1, this.pump1] = await deployMockBeanWell(
      BEAN_WSTETH_WELL,
      WETH
    );
    await this.beanEthWell.setReserves([to6("1000000"), to18("1000")]);
    await this.beanWstethWell.setReserves([to6("1000000"), to18("1000")]);
    await advanceTime(3600);
    await owner.sendTransaction({ to: user.address, value: 0 });
    await setToSecondsAfterHour(0);
    await owner.sendTransaction({ to: user.address, value: 0 });
    await beanstalk.connect(user).sunrise();
    await this.beanEthWell.connect(user).mint(user.address, to18("1000"));

    // init eth/usd oracles
    await setEthUsdChainlinkPrice("1000");
  });

  beforeEach(async function () {
    snapshotId = await takeSnapshot();
  });

  afterEach(async function () {
    await revertToSnapshot(snapshotId);
  });

  describe("previous balance = 0", async function () {
    beforeEach(async function () {
      await this.beanEthWell.setReserves([to6("0"), to18("0")]);
      await advanceTime(3600);
    });

    it("season incentive", async function () {
      await setToSecondsAfterHour(0);
      await beanstalk.connect(owner).sunrise();
      expect(await bean.balanceOf(owner.address)).to.be.equal(to6("5"));
    });

    it("30 seconds after season incentive", async function () {
      await setToSecondsAfterHour(30);
      await beanstalk.connect(owner).sunrise();
      // 5 * 1_347_849
      expect(await bean.balanceOf(owner.address)).to.be.equal(to6("6.739245"));
    });

    it("300 seconds after season incentive", async function () {
      await setToSecondsAfterHour(300);
      await beanstalk.connect(owner).sunrise();
      // 5 * 1_347_849
      expect(await bean.balanceOf(owner.address)).to.be.equal(to6("98.942330"));
    });

    it("1500 seconds after season incentive", async function () {
      await setToSecondsAfterHour(1500);
      await beanstalk.connect(owner).sunrise();
      expect(await bean.balanceOf(owner.address)).to.be.equal(to6("98.942330"));
    });
  });
});
