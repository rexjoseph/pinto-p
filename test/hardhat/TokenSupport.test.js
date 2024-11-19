const { expect } = require("chai");
const { deploy } = require("../../scripts/deploy.js");
const { getBeanstalk } = require("../../utils/contracts.js");
const { PIPELINE } = require("./utils/constants.js");
const { takeSnapshot, revertToSnapshot } = require("./utils/snapshot");

let user, owner;

describe("External Token", function () {
  before(async function () {
    [owner, user, user2] = await ethers.getSigners();
    const contracts = await deploy((verbose = false), (mock = true), (reset = true));
    beanstalk = await getBeanstalk(contracts.beanstalkDiamond.address);

    const Token = await ethers.getContractFactory("MockToken");
    this.token = await Token.deploy("Silo", "SILO");
    await this.token.deployed();

    this.erc1155 = await (await ethers.getContractFactory("MockERC1155", owner)).deploy("Mock");
    await this.erc1155.connect(user).setApprovalForAll(beanstalk.address, true);

    this.erc721 = await (await ethers.getContractFactory("MockERC721", owner)).deploy();
  });

  beforeEach(async function () {
    snapshotId = await takeSnapshot();
  });

  afterEach(async function () {
    await revertToSnapshot(snapshotId);
  });

  describe("Transfer ERC-1155", async function () {
    beforeEach(async function () {
      await this.erc1155.mockMint(user.address, "0", "5");
      await beanstalk.connect(user).transferERC1155(this.erc1155.address, PIPELINE, "0", "2");
    });

    it("transfers ERC-1155", async function () {
      expect(await this.erc1155.balanceOf(PIPELINE, "0")).to.be.equal("2");
      expect(await this.erc1155.balanceOf(user.address, "0")).to.be.equal("3");
    });
  });

  describe("Batch Transfer ERC-1155", async function () {
    beforeEach(async function () {
      await this.erc1155.mockMint(user.address, "0", "5");
      await this.erc1155.mockMint(user.address, "1", "10");
      await beanstalk
        .connect(user)
        .batchTransferERC1155(this.erc1155.address, PIPELINE, ["0", "1"], ["2", "3"]);
    });

    it("transfers ERC-1155", async function () {
      const balances = await this.erc1155.balanceOfBatch(
        [PIPELINE, PIPELINE, user.address, user.address],
        ["0", "1", "0", "1"]
      );
      expect(balances[0]).to.be.equal("2");
      expect(balances[1]).to.be.equal("3");
      expect(balances[2]).to.be.equal("3");
      expect(balances[3]).to.be.equal("7");
    });
  });

  describe("Transfer ERC-721", async function () {
    beforeEach(async function () {
      await this.erc721.mockMint(user.address, "0");
      await this.erc721.connect(user).approve(beanstalk.address, "0");
      await beanstalk.connect(user).transferERC721(this.erc721.address, PIPELINE, "0");
    });

    it("transfers ERC-721", async function () {
      expect(await this.erc721.ownerOf("0")).to.be.equal(PIPELINE);
    });
  });
});
