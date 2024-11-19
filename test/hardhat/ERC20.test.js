const { to6 } = require("./utils/helpers.js");
const { BEANSTALK } = require("./utils/constants.js");
const { expect } = require("chai");
const { takeSnapshot, revertToSnapshot } = require("./utils/snapshot.js");

let snapshotId;

describe("ERC-20", function () {
  before(async function () {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [BEANSTALK]
    });

    [owner, user, user2] = await ethers.getSigners();

    const Bean = await ethers.getContractFactory("Bean", owner);
    bean = await Bean.deploy();
    await bean.deployed();
    await bean.mint(user.address, to6("100"));
    console.log("Bean deployed to:", bean.address);
  });

  beforeEach(async function () {
    snapshotId = await takeSnapshot();
  });

  afterEach(async function () {
    await revertToSnapshot(snapshotId);
  });

  describe("mint", async function () {
    it("mints if minter", async function () {
      await bean.mint(user2.address, to6("100"));
      expect(await bean.balanceOf(user2.address)).to.be.equal(to6("100"));
    });

    it("reverts if not minter", async function () {
      await expect(bean.connect(user).mint(user2.address, to6("100"))).to.be.revertedWith(
        "!Minter"
      );
    });
  });
});
