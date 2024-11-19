const { BEANSTALK, MAX_UINT256 } = require("./constants");
const { to6 } = require("./helpers");
// general beanstalk test helpers to assist with testing.

/**
 * @notice initializes the array of users.
 * @dev
 * - approves beanstalk to use all beans.
 * - mints `amount` to `users`.
 */
async function initializeUsersForToken(tokenAddress, users, amount) {
  const token = await ethers.getContractAt("MockToken", tokenAddress);
  for (let i = 0; i < users.length; i++) {
    await token.connect(users[i]).approve(BEANSTALK, MAX_UINT256);
    await token.mint(users[i].address, amount);
  }
  return token;
}

/**
 * ends germination for the beanstalk, by elapsing 2 seasons.
 * @dev mockBeanstalk should be initialized prior to calling this function.
 */
async function endGermination() {
  await mockBeanstalk.siloSunrise(to6("0"));
  await mockBeanstalk.siloSunrise(to6("0"));
}

/**
 * ends germination for the beanstalk, by elapsing 2 seasons.
 * Also ends total germination for a specific token.
 * @dev mockBeanstalk should be initialized prior to calling this function.
 */
async function endGerminationWithMockToken(token) {
  await mockBeanstalk.siloSunrise(to6("0"));
  await mockBeanstalk.siloSunrise(to6("0"));
  await mockBeanstalk.mockEndTotalGerminationForToken(token);
}

exports.endGermination = endGermination;
exports.endGerminationWithMockToken = endGerminationWithMockToken;
exports.initializeUsersForToken = initializeUsersForToken;
