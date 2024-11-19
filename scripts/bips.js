const { BEANSTALK } = require("../test/hardhat/utils/constants");
const { impersonateBeanstalkOwner, mintEth } = require("../utils");
const { upgradeWithNewFacets } = require("./diamond.js");

async function mockBeanstalkAdmin(mock = true, account = undefined) {
  if (account == undefined) {
    account = await impersonateBeanstalkOwner();
    await mintEth(account.address);
  }

  await upgradeWithNewFacets({
    diamondAddress: BEANSTALK,
    facetNames: ["MockAdminFacet"],
    bip: false,
    object: !mock,
    verbose: true,
    account: account,
    verify: false
  });
}

exports.mockBeanstalkAdmin = mockBeanstalkAdmin;
