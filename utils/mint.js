const { USDC_MINTER } = require("../test/hardhat/utils/constants.js");
const { getUsdc, getBeanstalkAdminControls } = require("./contracts.js");
const { impersonateSigner } = require("./signer.js");

async function mintUsdc(address, amount) {
  await mintEth(USDC_MINTER);
  const signer = await impersonateSigner(USDC_MINTER);
  const usdc = await getUsdc();
  await usdc.connect(signer).mint(address, amount);
}

async function mintBeans(address, amount) {
  const beanstalkAdmin = await getBeanstalkAdminControls();
  await beanstalkAdmin.mintBeans(address, amount);
}

async function mintEth(address) {
  const clientVersion = await hre.network.provider.send("web3_clientVersion");
  const method = clientVersion.toLowerCase().includes("anvil")
    ? "anvil_setBalance"
    : "hardhat_setBalance";

  await hre.network.provider.send(method, [address, "0x21E19E0C9BAB2400000"]);
}

exports.mintEth = mintEth;
exports.mintUsdc = mintUsdc;
exports.mintBeans = mintBeans;
