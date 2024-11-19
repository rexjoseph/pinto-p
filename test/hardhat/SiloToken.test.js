const { expect } = require("chai");
const { deploy } = require("../../scripts/deploy.js");
const { getAllBeanstalkContracts } = require("../../utils/contracts");
const { readPrune, toBN } = require("../../utils");
const { EXTERNAL } = require("./utils/balances.js");
const { MAX_UINT256 } = require("./utils/constants");
const { to18 } = require("./utils/helpers.js");
const { takeSnapshot, revertToSnapshot } = require("./utils/snapshot");
const { initializeUsersForToken, endGermination } = require("./utils/testHelpers.js");

let user, user2, owner;

describe("New Silo Token", function () {
  before(async function () {
    pru = await readPrune();
    [owner, user, user2, flashLoanExploiter] = await ethers.getSigners();
    const contracts = await deploy((verbose = false), (mock = true), (reset = true));

    owner.address = contracts.account;
    this.diamond = contracts.beanstalkDiamond;
    // `beanstalk` contains all functions that the regular beanstalk has.
    // `mockBeanstalk` has functions that are only available in the mockFacets.
    [beanstalk, mockBeanstalk] = await getAllBeanstalkContracts(this.diamond.address);

    const SiloToken = await ethers.getContractFactory("MockToken");
    siloToken = await SiloToken.deploy("Silo", "SILO");
    await siloToken.deployed();

    siloToken2 = await SiloToken.deploy("Silo", "SILO");
    await siloToken2.deployed();

    await mockBeanstalk.mockWhitelistToken(
      siloToken.address,
      mockBeanstalk.interface.getSighash("mockBDV(uint256 amount)"),
      "10000000000",
      1e6 //aka "1 seed"
    );

    await initializeUsersForToken(
      siloToken.address,
      [user, user2, owner, flashLoanExploiter],
      to18("100000000000")
    );

    await siloToken2.connect(user).approve(beanstalk.address, MAX_UINT256);
    await siloToken2.mint(user.address, "10000");
  });

  beforeEach(async function () {
    snapshotId = await takeSnapshot();
  });

  afterEach(async function () {
    await revertToSnapshot(snapshotId);
  });

  describe("deposit", function () {
    describe("reverts", function () {
      it("reverts if BDV is 0", async function () {
        await expect(
          beanstalk.connect(user).deposit(siloToken.address, "0", EXTERNAL)
        ).to.revertedWith("Silo: No Beans under Token.");
      });

      it("reverts if deposits a non whitelisted token", async function () {
        await expect(
          beanstalk.connect(user).deposit(siloToken2.address, "0", EXTERNAL)
        ).to.revertedWith("Silo: Token not whitelisted");
      });
    });

    describe("single deposit", function () {
      beforeEach(async function () {
        this.result = await beanstalk.connect(user).deposit(siloToken.address, "1000", EXTERNAL);
        depositStem = await beanstalk.stemTipForToken(siloToken.address);
        await endGermination();
      });

      it("properly updates the total balances", async function () {
        expect(await beanstalk.getTotalDeposited(siloToken.address)).to.eq("1000");
        expect(await beanstalk.getGerminatingTotalDeposited(siloToken.address)).to.eq("0");
        expect(await beanstalk.getTotalDepositedBdv(siloToken.address)).to.eq("1000");
        expect(await beanstalk.getGerminatingTotalDepositedBdv(siloToken.address)).to.eq("0");
        expect(await beanstalk.totalStalk()).to.eq("10000000000000");
      });

      it("properly updates the user balance", async function () {
        expect(await beanstalk.balanceOfStalk(user.address)).to.eq("10000000000000");
      });

      it("properly adds the crate", async function () {
        const deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
        expect(deposit[0]).to.eq("1000");
        expect(deposit[1]).to.eq("1000");
      });

      it("emits Deposit event", async function () {
        await expect(this.result).to.emit(beanstalk, "AddDeposit").withArgs(
          user.address, // address of depositor.
          siloToken.address, // token deposited.
          depositStem, // stem at deposit.
          "1000", // amount deposited.
          "1000" // bdv deposited.
        );
      });

      //it uses grownStalkForDeposit to verify the deposit amount is correct
      it("verifies the grown stalk for deposit is correct", async function () {
        // deposit has grown 2 seeds worth of stalk, as 2 seasons has elasped.
        expect(
          await beanstalk.grownStalkForDeposit(user.address, siloToken.address, depositStem)
        ).to.eq("2000000000");

        // verify the function changes after a season has elapsed.
        await mockBeanstalk.lightSunrise();

        expect(
          await beanstalk.grownStalkForDeposit(user.address, siloToken.address, depositStem)
        ).to.eq("3000000000");
      });
    });

    describe("2 deposits same grown stalk per bdv", function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "1000", EXTERNAL);
        await beanstalk.connect(user).deposit(siloToken.address, "1000", EXTERNAL);
        depositStem = await beanstalk.stemTipForToken(siloToken.address);
        await endGermination();
      });

      it("properly updates the total balances", async function () {
        expect(await beanstalk.getTotalDeposited(siloToken.address)).to.eq("2000");
        expect(await beanstalk.getGerminatingTotalDeposited(siloToken.address)).to.eq("0");
        expect(await beanstalk.getTotalDepositedBdv(siloToken.address)).to.eq("2000");
        expect(await beanstalk.getGerminatingTotalDepositedBdv(siloToken.address)).to.eq("0");
        expect(await beanstalk.totalStalk()).to.eq("20000000000000");
      });

      it("properly updates the user balance", async function () {
        expect(await beanstalk.balanceOfStalk(user.address)).to.eq("20000000000000");
      });

      it("properly adds the crate", async function () {
        const deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
        expect(deposit[0]).to.eq("2000");
        expect(deposit[1]).to.eq("2000");
      });
    });

    describe("2 deposits 2 users", function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "1000", EXTERNAL);
        await beanstalk.connect(user2).deposit(siloToken.address, "1000", EXTERNAL);
        depositStem = await beanstalk.stemTipForToken(siloToken.address);

        // end germination for the mock token.
        await endGermination();
      });

      it("properly updates the total balances", async function () {
        expect(await beanstalk.getTotalDeposited(siloToken.address)).to.eq("2000");
        expect(await beanstalk.getGerminatingTotalDeposited(siloToken.address)).to.eq("0");
        expect(await beanstalk.getTotalDepositedBdv(siloToken.address)).to.eq("2000");
        expect(await beanstalk.getGerminatingTotalDepositedBdv(siloToken.address)).to.eq("0");
        expect(await beanstalk.totalStalk()).to.eq("20000000000000");
      });

      it("properly updates the user balance", async function () {
        expect(await beanstalk.balanceOfStalk(user.address)).to.eq("10000000000000");
      });
      it("properly updates the user2 balance", async function () {
        expect(await beanstalk.balanceOfStalk(user2.address)).to.eq("10000000000000");
      });

      it("properly adds the crate", async function () {
        let deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
        expect(deposit[0]).to.eq("1000");
        expect(deposit[1]).to.eq("1000");
        deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem);
        expect(deposit[0]).to.eq("1000");
        expect(deposit[1]).to.eq("1000");
      });
    });
  });

  describe("withdraw", function () {
    beforeEach(async function () {
      await beanstalk.connect(user).deposit(siloToken.address, "1000", EXTERNAL);
      depositStem = await beanstalk.stemTipForToken(siloToken.address);
    });
    describe("reverts", function () {
      it("reverts if amount is 0", async function () {
        await expect(
          beanstalk.connect(user).withdrawDeposit(siloToken.address, depositStem, "1001", EXTERNAL)
        ).to.revertedWith("Silo: Crate balance too low.");
      });

      it("reverts if deposits + withdrawals is a different length", async function () {
        await expect(
          beanstalk
            .connect(user)
            .withdrawDeposits(siloToken.address, ["1", "2"], ["1001"], EXTERNAL)
        ).to.revertedWith("Silo: Crates, amounts are diff lengths.");
      });
    });

    describe("withdraw token by season", async function () {
      describe("withdraw 1 Bean crate", async function () {
        beforeEach(async function () {
          userBalanceBefore = await siloToken.balanceOf(user.address);
          this.result = await beanstalk
            .connect(user)
            .withdrawDeposit(siloToken.address, depositStem, "1000", EXTERNAL);
        });

        it("properly updates the total balances", async function () {
          expect(await beanstalk.getTotalDeposited(siloToken.address)).to.eq("0");
          expect(await beanstalk.getTotalDepositedBdv(siloToken.address)).to.eq("0");
          expect(await beanstalk.totalStalk()).to.eq("0");
        });

        it("properly updates the user balance", async function () {
          expect(await beanstalk.balanceOfStalk(user.address)).to.eq("0");
          expect((await siloToken.balanceOf(user.address)).sub(userBalanceBefore)).to.eq("1000");
        });

        it("properly removes the deposit", async function () {
          const deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
          expect(deposit[0]).to.eq("0");
          expect(deposit[1]).to.eq("0");
        });

        it("emits RemoveDeposit event", async function () {
          await expect(this.result).to.emit(beanstalk, "RemoveDeposit").withArgs(
            user.address, // user that withdrew from the silo.
            siloToken.address, // token of withdrawal.
            depositStem, // stem
            "1000", // amount
            "1000" // bdv
          );
        });
      });

      describe("withdraw part of a bean crate", function () {
        beforeEach(async function () {
          this.result = await beanstalk
            .connect(user)
            .withdrawDeposit(siloToken.address, depositStem, "500", EXTERNAL);
        });

        it("properly updates the total balances", async function () {
          expect(await beanstalk.getGerminatingTotalDeposited(siloToken.address)).to.eq("500");
          expect(await beanstalk.getGerminatingTotalDepositedBdv(siloToken.address)).to.eq("500");
          // no stalk is active as the deposit is in the germinating period.
          expect(await beanstalk.totalStalk()).to.eq("0");
          expect(
            (await beanstalk.getGerminatingStalkAndRootsForSeason(await beanstalk.season()))[0]
          ).to.eq("5000000000000");
        });

        it("properly updates the user balance", async function () {
          // user should not have any stalk, but should have germinating stalk.
          expect(await beanstalk.balanceOfStalk(user.address)).to.eq("0");
          expect(await beanstalk.balanceOfGerminatingStalk(user.address)).to.eq("5000000000000");
          expect((await siloToken.balanceOf(user.address)).sub(userBalanceBefore)).to.eq("500");
        });

        it("properly removes the deposit", async function () {
          const deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
          expect(deposit[0]).to.eq("500");
          expect(deposit[1]).to.eq("500");
        });

        it("emits RemoveDeposit event", async function () {
          await expect(this.result)
            .to.emit(beanstalk, "RemoveDeposit")
            .withArgs(user.address, siloToken.address, depositStem, "500", "500");
        });
      });
    });

    describe("withdraw token by seasons", async function () {
      describe("1 full and 1 partial token crates", function () {
        beforeEach(async function () {
          const stem0 = await beanstalk.stemTipForToken(siloToken.address);
          await mockBeanstalk.siloSunrise(0);
          const stem1 = await beanstalk.stemTipForToken(siloToken.address);
          await beanstalk.connect(user).deposit(siloToken.address, "1000", EXTERNAL);
          userBalanceBefore = await siloToken.balanceOf(user.address);
          this.result = await beanstalk
            .connect(user)
            .withdrawDeposits(siloToken.address, [stem0, stem1], ["500", "1000"], EXTERNAL);
        });

        it("properly updates the total balances", async function () {
          expect(await beanstalk.getTotalDeposited(siloToken.address)).to.eq("0");
          expect(await beanstalk.getTotalDepositedBdv(siloToken.address)).to.eq("0");
          expect(await beanstalk.getGerminatingTotalDeposited(siloToken.address)).to.eq("500");
          expect(await beanstalk.getGerminatingTotalDepositedBdv(siloToken.address)).to.eq("500");
          expect(await beanstalk.totalStalk()).to.eq("500000000");
          expect(
            (
              await beanstalk.getGerminatingStalkAndRootsForSeason(
                toBN(await beanstalk.season()).sub("1")
              )
            )[0]
          ).to.eq("5000000000000");
        });
        it("properly updates the user balance", async function () {
          // the user should have 500 microStalk, and 5e6 germinating stalk.
          expect(await beanstalk.balanceOfStalk(user.address)).to.eq("500000000");
          expect(await beanstalk.balanceOfGerminatingStalk(user.address)).to.eq("5000000000000");
          expect((await siloToken.balanceOf(user.address)).sub(userBalanceBefore)).to.eq("1500");
        });
        it("properly removes the crate", async function () {
          const siloSettings = await beanstalk.tokenSettings(siloToken.address);
          const stem1 = await beanstalk.stemTipForToken(siloToken.address);
          const stem0 = stem1.sub(siloSettings.stalkEarnedPerSeason);
          let dep = await beanstalk.getDeposit(user.address, siloToken.address, stem0);
          expect(dep[0]).to.equal("500");
          expect(dep[1]).to.equal("500");
          dep = await beanstalk.getDeposit(user.address, siloToken.address, stem1);
          expect(dep[0]).to.equal("0");
          expect(dep[1]).to.equal("0");
        });

        it("emits RemoveDeposits event", async function () {
          const siloSettings = await beanstalk.tokenSettings(siloToken.address);
          const stem1 = await beanstalk.stemTipForToken(siloToken.address);
          const stem0 = stem1.sub(siloSettings.stalkEarnedPerSeason);
          await expect(this.result)
            .to.emit(beanstalk, "RemoveDeposits")
            .withArgs(user.address, siloToken.address, [stem0, stem1], ["500", "1000"], "1500", [
              "500",
              "1000"
            ]);
        });
      });

      describe("2 token crates", function () {
        beforeEach(async function () {
          const stem0 = await beanstalk.stemTipForToken(siloToken.address);
          await mockBeanstalk.siloSunrise(0);
          const stem1 = await beanstalk.stemTipForToken(siloToken.address);

          await beanstalk.connect(user).deposit(siloToken.address, "1000", EXTERNAL);
          userBalanceBefore = await siloToken.balanceOf(user.address);
          this.result = await beanstalk
            .connect(user)
            .withdrawDeposits(siloToken.address, [stem0, stem1], ["1000", "1000"], EXTERNAL);
        });

        it("properly updates the total balances", async function () {
          expect(await beanstalk.getTotalDeposited(siloToken.address)).to.eq("0");
          expect(await beanstalk.getTotalDepositedBdv(siloToken.address)).to.eq("0");
          expect(await beanstalk.totalStalk()).to.eq("0");
        });

        it("properly updates the user balance", async function () {
          expect(await beanstalk.balanceOfStalk(user.address)).to.eq("0");
          expect((await siloToken.balanceOf(user.address)).sub(userBalanceBefore)).to.eq("2000");
        });

        it("properly removes the crate", async function () {
          let dep = await beanstalk.getDeposit(user.address, siloToken.address, 0);
          expect(dep[0]).to.equal("0");
          expect(dep[1]).to.equal("0");
          dep = await beanstalk.getDeposit(user.address, siloToken.address, 1);
          expect(dep[0]).to.equal("0");
          expect(dep[1]).to.equal("0");
        });
        it("emits RemoveDeposits event", async function () {
          const siloSettings = await beanstalk.tokenSettings(siloToken.address);
          const stem1 = await beanstalk.stemTipForToken(siloToken.address);
          const stem0 = stem1.sub(siloSettings.stalkEarnedPerSeason);
          await expect(this.result)
            .to.emit(beanstalk, "RemoveDeposits")
            .withArgs(user.address, siloToken.address, [stem0, stem1], ["1000", "1000"], "2000", [
              "1000",
              "1000"
            ]);
        });
      });
    });
  });

  describe("Transfer", async function () {
    describe("reverts", async function () {
      it("reverts if the amounts array is empty", async function () {
        await expect(
          beanstalk
            .connect(user)
            .transferDeposits(user.address, user2.address, siloToken.address, [], [])
        ).to.revertedWith("Silo: amounts array is empty");
      });

      it("reverts if the amount in array is 0", async function () {
        await expect(
          beanstalk
            .connect(user)
            .transferDeposits(
              user.address,
              user2.address,
              siloToken.address,
              ["2", "3"],
              ["100", "0"]
            )
        ).to.revertedWith("Silo: amount in array is 0");
      });
    });

    describe("Single", async function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        depositStem = await beanstalk.stemTipForToken(siloToken.address);

        // end germination for the mock token.
        await endGermination();

        await beanstalk.mow(user.address, siloToken.address);
        previousTotalStalk = await beanstalk.totalStalk();

        this.result = await beanstalk
          .connect(user)
          .callStatic.transferDeposit(
            user.address,
            user2.address,
            siloToken.address,
            depositStem,
            "50"
          );

        expect(this.result).to.be.equal("50");

        await beanstalk
          .connect(user)
          .transferDeposit(user.address, user2.address, siloToken.address, depositStem, "50");
      });

      it("removes the deposit from the sender", async function () {
        const deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
        expect(deposit[0]).to.equal("50");
        expect(deposit[1]).to.equal("50");
      });

      it("updates users stalk", async function () {
        expect(await beanstalk.balanceOfStalk(user.address)).to.be.equal("500100000000");
      });

      it("add the deposit to the recipient", async function () {
        const deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem);
        expect(deposit[0]).to.equal("50");
        expect(deposit[1]).to.equal("50");
      });

      it("updates users stalk", async function () {
        expect(await beanstalk.balanceOfStalk(user2.address)).to.be.equal("500100000000");
      });

      it("totalStalk is unchanged", async function () {
        expect(await beanstalk.totalStalk()).to.be.equal(previousTotalStalk);
      });
    });

    describe("Single all", async function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        depositStem = await beanstalk.stemTipForToken(siloToken.address);

        await endGermination();

        await beanstalk.mow(user.address, siloToken.address);
        prevTotalStalk = await beanstalk.totalStalk();
        prevUserStalk = await beanstalk.balanceOfStalk(user.address);

        await beanstalk
          .connect(user)
          .transferDeposit(user.address, user2.address, siloToken.address, depositStem, "100");
      });

      it("removes the deposit from the sender", async function () {
        const deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
        expect(deposit[0]).to.equal("0");
        expect(deposit[1]).to.equal("0");
      });

      it("updates users stalk and seeds", async function () {
        expect(await beanstalk.balanceOfStalk(user.address)).to.be.equal("0");
      });

      it("add the deposit to the recipient", async function () {
        const deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem);
        expect(deposit[0]).to.equal("100");
        expect(deposit[1]).to.equal("100");
      });

      it("updates users stalk and seeds", async function () {
        expect(await beanstalk.balanceOfStalk(user2.address)).to.be.equal(toBN(prevUserStalk));
      });

      it("totalStalk is unchanged", async function () {
        expect(await beanstalk.totalStalk()).to.be.equal(prevTotalStalk);
      });
    });

    describe("Multiple", async function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        depositStem0 = await beanstalk.stemTipForToken(siloToken.address);
        await mockBeanstalk.siloSunrise("0");
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        depositStem1 = await beanstalk.stemTipForToken(siloToken.address);

        await mockBeanstalk.siloSunrise("0");
        await mockBeanstalk.mockEndTotalGerminationForToken(siloToken.address);
        await mockBeanstalk.siloSunrise("0");
        await mockBeanstalk.mockEndTotalGerminationForToken(siloToken.address);

        let result = await beanstalk
          .connect(user)
          .callStatic.transferDeposits(
            user.address,
            user2.address,
            siloToken.address,
            [depositStem0, depositStem1],
            ["50", "25"]
          );

        expect(result[0]).to.eq("50");
        expect(result[1]).to.eq("25");

        await beanstalk
          .connect(user)
          .transferDeposits(
            user.address,
            user2.address,
            siloToken.address,
            [depositStem0, depositStem1],
            ["50", "25"]
          );
      });

      it("removes the deposit from the sender", async function () {
        let deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem0);
        expect(deposit[0]).to.equal("50");
        expect(deposit[1]).to.equal("50");
        deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem1);
        expect(deposit[0]).to.equal("75");
        expect(deposit[1]).to.equal("75");
      });

      it("updates users stalk and seeds", async function () {
        // 3 seasons have passed for 1 deposit and 2 season for the other. (500 total stalk)
        // (300 * 50%) + (200 * 75%) = 300
        expect(await beanstalk.balanceOfStalk(user.address)).to.be.equal("1250300000000");
      });

      it("add the deposit to the recipient", async function () {
        let deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem0);
        expect(deposit[0]).to.equal("50");
        expect(deposit[1]).to.equal("50");

        deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem1);
        expect(deposit[0]).to.equal("25");
        expect(deposit[1]).to.equal("25");
      });

      it("updates users stalk and seeds", async function () {
        // 3 seasons have passed for 1 deposit and 2 season for the other. (500 total stalk)
        // (300 * 50%) + (200 * 25%) = 200
        expect(await beanstalk.balanceOfStalk(user2.address)).to.be.equal("750200000000");
      });

      it("updates total stalk and seeds", async function () {
        expect(await beanstalk.totalStalk()).to.be.equal("2000500000000");
      });
    });

    describe("Single with allowance", async function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        await beanstalk
          .connect(user)
          .increaseDepositAllowance(owner.address, siloToken.address, "100");
        depositStem = await beanstalk.stemTipForToken(siloToken.address);
        await endGermination();

        await beanstalk
          .connect(owner)
          .transferDeposit(user.address, user2.address, siloToken.address, depositStem, "50");
      });

      it("removes the deposit from the sender", async function () {
        const deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
        expect(deposit[0]).to.equal("50");
        expect(deposit[1]).to.equal("50");
      });

      it("updates users stalk and seeds", async function () {
        expect(await beanstalk.balanceOfStalk(user.address)).to.be.equal("500100000000");
      });

      it("add the deposit to the recipient", async function () {
        const deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem);
        expect(deposit[0]).to.equal("50");
        expect(deposit[1]).to.equal("50");
      });

      it("updates users stalk and seeds", async function () {
        expect(await beanstalk.balanceOfStalk(user2.address)).to.be.equal("500100000000");
      });

      it("updates total stalk and seeds", async function () {
        expect(await beanstalk.totalStalk()).to.be.equal("1000200000000");
      });

      it("properly updates users token allowance", async function () {
        expect(
          await beanstalk.depositAllowance(user.address, owner.address, siloToken.address)
        ).to.be.equal("50");
      });
    });

    describe("Single with no allowance", async function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
      });

      it("reverts with no allowance", async function () {
        const stem = await beanstalk.stemTipForToken(siloToken.address);
        await expect(
          beanstalk
            .connect(owner)
            .transferDeposit(user.address, user2.address, siloToken.address, stem, "50")
        ).to.revertedWith("Silo: insufficient allowance");
      });
    });

    describe("Single all with allowance", async function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        await beanstalk
          .connect(user)
          .increaseDepositAllowance(owner.address, siloToken.address, "100");
        depositStem = await beanstalk.stemTipForToken(siloToken.address);
        await endGermination();

        await beanstalk
          .connect(owner)
          .transferDeposit(user.address, user2.address, siloToken.address, depositStem, "100");
      });

      it("removes the deposit from the sender", async function () {
        const deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem);
        expect(deposit[0]).to.equal("0");
        expect(deposit[1]).to.equal("0");
      });

      it("updates users stalk and seeds", async function () {
        expect(await beanstalk.balanceOfStalk(user.address)).to.be.equal("0");
      });

      it("add the deposit to the recipient", async function () {
        const deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem);
        expect(deposit[0]).to.equal("100");
        expect(deposit[1]).to.equal("100");
      });

      it("updates users stalk and seeds", async function () {
        expect(await beanstalk.balanceOfStalk(user2.address)).to.be.equal("1000200000000");
      });

      it("updates total stalk and seeds", async function () {
        expect(await beanstalk.totalStalk()).to.be.equal("1000200000000");
      });

      it("properly updates users token allowance", async function () {
        expect(
          await beanstalk.depositAllowance(user.address, owner.address, siloToken.address)
        ).to.be.equal("0");
      });
    });

    describe("Multiple with allowance", async function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        depositStem1 = await beanstalk.stemTipForToken(siloToken.address);
        await mockBeanstalk.siloSunrise("0");
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        depositStem2 = await beanstalk.stemTipForToken(siloToken.address);

        // call sunrise twice to trigger germination.
        await mockBeanstalk.siloSunrise("0");
        await mockBeanstalk.mockEndTotalGerminationForToken(siloToken.address);
        await mockBeanstalk.siloSunrise("0");
        await mockBeanstalk.mockEndTotalGerminationForToken(siloToken.address);

        await beanstalk
          .connect(user)
          .increaseDepositAllowance(owner.address, siloToken.address, "200");
        await beanstalk
          .connect(owner)
          .transferDeposits(
            user.address,
            user2.address,
            siloToken.address,
            [depositStem1, depositStem2],
            ["50", "25"]
          );
      });

      it("removes the deposit from the sender", async function () {
        let deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem1);
        expect(deposit[0]).to.equal("50");
        expect(deposit[1]).to.equal("50");
        deposit = await beanstalk.getDeposit(user.address, siloToken.address, depositStem2);
        expect(deposit[0]).to.equal("75");
        expect(deposit[1]).to.equal("75");
      });

      it("updates users stalk and seeds", async function () {
        expect(await beanstalk.balanceOfStalk(user.address)).to.be.equal("1250300000000");
      });

      it("add the deposit to the recipient", async function () {
        let deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem1);
        expect(deposit[0]).to.equal("50");
        expect(deposit[0]).to.equal("50");
        deposit = await beanstalk.getDeposit(user2.address, siloToken.address, depositStem2);
        expect(deposit[0]).to.equal("25");
        expect(deposit[0]).to.equal("25");
      });

      it("updates users stalk and seeds", async function () {
        expect(await beanstalk.balanceOfStalk(user2.address)).to.be.equal("750200000000");
      });

      it("updates total stalk and seeds", async function () {
        expect(await beanstalk.totalStalk()).to.be.equal("2000500000000");
      });

      it("properly updates users token allowance", async function () {
        expect(
          await beanstalk.depositAllowance(user.address, owner.address, siloToken.address)
        ).to.be.equal("125");
      });
    });

    describe("Multiple with no allowance", async function () {
      beforeEach(async function () {
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
        await mockBeanstalk.siloSunrise("0");
        await beanstalk.connect(user).deposit(siloToken.address, "100", EXTERNAL);
      });

      it("reverts with no allowance", async function () {
        const siloSettings = await beanstalk.tokenSettings(siloToken.address);
        const stem1 = await beanstalk.stemTipForToken(siloToken.address);
        const stem0 = stem1.sub(siloSettings.stalkEarnedPerSeason);
        await expect(
          beanstalk
            .connect(owner)
            .transferDeposits(
              user.address,
              user2.address,
              siloToken.address,
              [stem0, stem1],
              ["50", "25"]
            )
        ).to.revertedWith("Silo: insufficient allowance");
      });
    });
  });

  describe("Deposit Approval", async function () {
    describe("approve allowance", async function () {
      beforeEach(async function () {
        this.result = await beanstalk
          .connect(user)
          .increaseDepositAllowance(user2.address, siloToken.address, "100");
      });

      it("properly updates users token allowance", async function () {
        expect(
          await beanstalk.depositAllowance(user.address, user2.address, siloToken.address)
        ).to.be.equal("100");
      });

      it("emits DepositApproval event", async function () {
        await expect(this.result)
          .to.emit(beanstalk, "DepositApproval")
          .withArgs(user.address, user2.address, siloToken.address, "100");
      });
    });

    describe("increase and decrease allowance", async function () {
      beforeEach(async function () {
        await beanstalk
          .connect(user)
          .increaseDepositAllowance(user2.address, siloToken.address, "100");
      });

      it("properly increase users token allowance", async function () {
        await beanstalk
          .connect(user)
          .increaseDepositAllowance(user2.address, siloToken.address, "100");
        expect(
          await beanstalk.depositAllowance(user.address, user2.address, siloToken.address)
        ).to.be.equal("200");
      });

      it("properly decrease users token allowance", async function () {
        await beanstalk
          .connect(user)
          .decreaseDepositAllowance(user2.address, siloToken.address, "25");
        expect(
          await beanstalk.depositAllowance(user.address, user2.address, siloToken.address)
        ).to.be.equal("75");
      });

      it("decrease users token allowance below zero", async function () {
        await expect(
          beanstalk.connect(user).decreaseDepositAllowance(user2.address, siloToken.address, "101")
        ).to.revertedWith("Silo: decreased allowance below zero");
      });

      it("emits DepositApproval event on increase", async function () {
        const result = await beanstalk
          .connect(user)
          .increaseDepositAllowance(user2.address, siloToken.address, "25");
        await expect(result)
          .to.emit(beanstalk, "DepositApproval")
          .withArgs(user.address, user2.address, siloToken.address, "125");
      });

      it("emits DepositApproval event on decrease", async function () {
        const result = await beanstalk
          .connect(user)
          .decreaseDepositAllowance(user2.address, siloToken.address, "25");
        await expect(result)
          .to.emit(beanstalk, "DepositApproval")
          .withArgs(user.address, user2.address, siloToken.address, "75");
      });
    });
  });

  // the germination update prevents the flash loan exploit where
  // a user can deposit, call sunrise, withdraw and earn beans.
  // however, there is an edge case where the first deposit earns the beans,
  // with the grown stalk, as roots are not initialized. This is acceptable
  // given that it only occurs with no deposits and is highly unlikely to occur.
  // additionally, a fresh beanstalk can prevent this from occuring by depositing beans
  // and burning the deposit on the init contract.
  describe("flash loan exploit", async function () {
    before(async function () {
      // user 1 and user 2 deposits 1000 beans into the silo.
      await beanstalk.connect(user).deposit(siloToken.address, "1000", EXTERNAL);
      await beanstalk.connect(user2).deposit(siloToken.address, "1000", EXTERNAL);
      // call sunrise twice and end germination process for mock silo token.
      await endGermination();
    });
    beforeEach(async function () {
      // craft transaction for flashLoanExploiter to deposit, call sunrise (with some beans minted), and withdraw.
      await network.provider.send("evm_setAutomine", [false]);
      await beanstalk.connect(flashLoanExploiter).deposit(siloToken.address, "1000", EXTERNAL);
      stem = await beanstalk.stemTipForToken(siloToken.address);
      await mockBeanstalk.connect(user).siloSunrise(100);
      await beanstalk
        .connect(flashLoanExploiter)
        .withdrawDeposit(siloToken.address, stem, "1000", EXTERNAL);
      await network.provider.send("evm_mine");
      await network.provider.send("evm_setAutomine", [true]);
    });

    it("does not allocate bean mints to the user", async function () {
      await expect(await beanstalk.balanceOfEarnedBeans(flashLoanExploiter.address)).to.eq("0");
    });

    it("loses all stalk", async function () {
      await expect(
        await beanstalk.balanceOfGrownStalk(flashLoanExploiter.address, siloToken.address)
      ).to.eq("0");
      await expect(await beanstalk.balanceOfStalk(flashLoanExploiter.address)).to.eq("0");
      await expect(await beanstalk.balanceOfRoots(flashLoanExploiter.address)).to.eq("0");
    });
  });
});
