const { expect } = require("chai");
const { deploy } = require("../../scripts/deploy.js");
const { takeSnapshot, revertToSnapshot } = require("./utils/snapshot.js");
const { BEAN, ZERO_ADDRESS, BEAN_WSTETH_WELL, WSTETH } = require("./utils/constants.js");
const { to18, to6 } = require("./utils/helpers.js");
const { deployMockWellWithMockPump } = require("../../utils/well.js");
const { getAllBeanstalkContracts } = require("../../utils/contracts.js");
const { getBean } = require("../../utils/index.js");

let user, owner;

let snapshotId;

describe("BDV", function () {
  before(async function () {
    [owner, user, user2] = await ethers.getSigners();

    const contracts = await deploy((verbose = false), (mock = true), (reset = true));
    ownerAddress = contracts.account;
    this.diamond = contracts.beanstalkDiamond;
    // `beanstalk` contains all functions that the regular beanstalk has.
    // `mockBeanstalk` has functions that are only available in the mockFacets.
    [beanstalk, mockBeanstalk] = await getAllBeanstalkContracts(this.diamond.address);

    bean = await getBean();

    [this.well, this.wellFunction, this.pump] = await deployMockWellWithMockPump(
      BEAN_WSTETH_WELL,
      WSTETH
    );

    await mockBeanstalk.siloSunrise(0);
    await bean.mint(user.address, "1000000000");
    await bean.mint(ownerAddress, "1000000000");
    await this.well.connect(user).approve(beanstalk.address, "100000000000");
    await bean.connect(user).approve(beanstalk.address, "100000000000");
    await bean.connect(owner).approve(beanstalk.address, "100000000000");
    await this.well.mint(user.address, "10000");
    await this.well.mint(ownerAddress, to18("1000"));
    await this.well.approve(beanstalk.address, to18("1000"));
  });

  beforeEach(async function () {
    snapshotId = await takeSnapshot();
  });

  afterEach(async function () {
    await revertToSnapshot(snapshotId);
  });

  describe("Bean BDV", async function () {
    it("properly checks bdv", async function () {
      expect(await beanstalk.bdv(BEAN, to6("200"))).to.equal(to6("200"));
    });
  });

  it("reverts if not correct", async function () {
    await expect(beanstalk.bdv(ZERO_ADDRESS, to18("2000"))).to.be.revertedWith(
      "Silo: Token not whitelisted"
    );
  });
});
