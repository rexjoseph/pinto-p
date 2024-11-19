const {
  upgradeWithNewFacets,
  deployFacetsAndLibraries,
  upgradeWithDeployedFacets,
  deployDiamond
} = require("../diamond.js");
const { parseDeploymentParameters } = require("./parameters/parseParams.js");
const { uncommentOracleTimeout } = require("./parameters/regex/updateOracleTimeout.js");
const {
  facets,
  libraryNames,
  facetLibraries,
  libraryLinks
} = require("../../test/hardhat/utils/facets.js");
const { deployContract } = require("../contracts.js");
const { addInitialLiquidityAndDeposit } = require("./addLiquidity.js");

async function megaInit({
  deployer = undefined,
  deployerAddress = undefined,
  ownerAddress = undefined,
  diamondName = undefined,
  updateOracleTimeout = true,
  addLiquidity = true,
  skipInitialAmountPrompts = true,
  verbose = true,
  mock = false
}) {
  //////////////////// Parse Parameters //////////////////////
  // Deployment parameters path
  const inputFilePath = "./scripts/deployment/parameters/input/deploymentParams.json";
  let [systemData, whitelistData, wellData, tokenData, initWellDistributions, initSupply] =
    await parseDeploymentParameters(inputFilePath, updateOracleTimeout);

  // recompile to get the updated artifacts
  console.log("\nRecompiling contracts with updated constant and timeout...");
  await hre.run("compile");

  //////////////////// Deploy Diamond //////////////////////
  // note: at first, the deployer is the owner and then proposes ownership
  // to the pcm in the init protocol script.
  console.log("\nDeploying Pinto Diamond...");
  console.log("-----------------------------------\n");
  const diamond = await deployDiamond({
    diamondName: diamondName,
    ownerAddress: deployerAddress,
    deployer: deployer,
    args: [],
    verbose: verbose
  });
  console.log(`\n${diamondName} deployed at: ${diamond.address}`);

  // Deploy price contract
  await deployContract("BeanstalkPrice", deployer, verbose, [diamond.address]);

  //////////////////// Deploy Facets and Libraries //////////////////////
  console.log("\nDeploying facets and libraries...");
  console.log("-----------------------------------\n");
  const deployedFacets = await deployFacetsAndLibraries({
    facets: facets,
    libraryNames: libraryNames,
    facetLibraries: facetLibraries,
    libraryLinks: libraryLinks,
    account: deployer,
    verbose: verbose
  });
  console.log("\nFacets and libraries deployed.");

  //////////////////// Execute protocol init script //////////////////////
  console.log("---------------------------------------\n");
  console.log("\nExecuting protocol init script...");
  await upgradeWithNewFacets({
    diamondAddress: diamond.address,
    facetNames: [],
    initFacetName: "InitProtocol",
    initArgs: [systemData, tokenData, ownerAddress],
    account: deployer,
    verbose: verbose
  });
  console.log("\nProtocol init script executed.");

  //////////////////// Execute wells and whitelist init script //////////////////////
  console.log("---------------------------------------\n");
  console.log("\nExecuting wells init script...");
  await upgradeWithNewFacets({
    diamondAddress: diamond.address,
    facetNames: [],
    initFacetName: "InitWells",
    initArgs: [wellData, whitelistData],
    account: deployer,
    verbose: verbose
  });
  console.log("\nWells init script executed.");

  // get the addresses of deployed facets
  const facetNames = [];
  const facetAddresses = [];
  for (const facetName in deployedFacets) {
    if (verbose) console.log(`${facetName} deployed at ${deployedFacets[facetName].address}`);
    facetNames.push(facetName);
    facetAddresses.push(deployedFacets[facetName].address);
  }

  //////////////////// Link deployed facets to diamond //////////////////////
  console.log("---------------------------------------\n");
  console.log("\nLinking deployed facets to diamond...");
  await upgradeWithDeployedFacets({
    diamondAddress: diamond.address,
    facetNames: facetNames,
    facetAddresses: facetAddresses,
    verbose: verbose,
    account: deployer,
    object: false // true to save diamond cut json, false to upgrade diamond
  });
  console.log("\nDeployment Successful!");

  ////////////// Deposit from Receiver to Well //////////////
  if (addLiquidity) {
    console.log("---------------------------------------\n");
    for (const distribution of initWellDistributions) {
      const usdAmount = initSupply * (parseFloat(distribution.initSupplyPercentage) / 100);
      console.log(
        `\nDepositing ${usdAmount} PINTO and ${usdAmount} USD worth of Non Pinto Token to ${distribution.well} well`
      );
      await addInitialLiquidityAndDeposit(
        deployer,
        distribution.well,
        usdAmount,
        skipInitialAmountPrompts,
        mock
      );
    }
  }

  //////////////////// Revert Regex changes //////////////////////
  if (updateOracleTimeout) {
    console.log("---------------------------------------\n");
    const chainlinkPath = "./contracts/libraries/Oracle/LibChainlinkOracle.sol";
    uncommentOracleTimeout(chainlinkPath);
  }
}

exports.megaInit = megaInit;
