const { BEANSTALK } = require("../test/hardhat/utils/constants");
const { getBeanstalk } = require("../utils");
const { upgradeWithNewFacets } = require("./diamond");

async function epipSample() {
  beanstalk = await getBeanstalk();
  await upgradeWithNewFacets({
    diamondAddress: BEANSTALK,
    facetNames: ["SampleFacet"],
    initFacetName: "SampleFacet",
    bip: false,
    object: !mock,
    verbose: true,
    account: account,
    verify: false
  });
}

export { epipSample };
