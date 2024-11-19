const toBytes32 = (bn) => {
  return ethers.utils.hexlify(ethers.utils.zeroPad(bn.toHexString(), 32));
};

const setStorageAt = async (address, index, value) => {
  await ethers.provider.send("hardhat_setStorageAt", [address, index, value]);
  await ethers.provider.send("evm_mine", []); // Just mines to the next block
};

const getIndex = async (userAddress, balanceSlot) => {
  return ethers.utils.solidityKeccak256(
    ["uint256", "uint256"],
    [userAddress, balanceSlot] // key, slot
  );
};

async function setBalanceAtSlot(tokenAddress, userAddress, balanceSlot, balance, verbose = false) {
  const index = await getIndex(userAddress, balanceSlot);
  await setStorageAt(tokenAddress, index.toString(), toBytes32(balance).toString());
  if (verbose) {
    console.log(`Set balance at slot ${balanceSlot} for user ${userAddress} to ${balance}`);
  }
}

exports.setBalanceAtSlot = setBalanceAtSlot;
