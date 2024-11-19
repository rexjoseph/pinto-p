const { defaultAbiCoder } = require("@ethersproject/abi");

// Copied from LibConvertData.sol
const ConvertKind = {
  LAMBDA_LAMBDA: 0,
  BEANS_TO_WELL_LP: 1,
  WELL_LP_TO_BEANS: 2,
  ANTI_LAMBDA_LAMBDA: 3
};

class ConvertEncoder {
  /**
   * Cannot be constructed.
   */
  constructor() {
    // eslint-disable-next-line @javascript-eslint/no-empty-function
  }

  static convertLambdaToLambda = (amount, token) =>
    defaultAbiCoder.encode(
      ["uint256", "uint256", "address"],
      [ConvertKind.LAMBDA_LAMBDA, amount, token]
    );

  static convertWellLPToBeans = (lp, minBeans, address) =>
    defaultAbiCoder.encode(
      ["uint256", "uint256", "uint256", "address"],
      [ConvertKind.WELL_LP_TO_BEANS, lp, minBeans, address]
    );

  static convertBeansToWellLP = (beans, minLP, address) =>
    defaultAbiCoder.encode(
      ["uint256", "uint256", "uint256", "address"],
      [ConvertKind.BEANS_TO_WELL_LP, beans, minLP, address]
    );

  static convertAntiLambdaToLambda = (amount, token, account) =>
    defaultAbiCoder.encode(
      ["uint256", "uint256", "address", "address"],
      [ConvertKind.ANTI_LAMBDA_LAMBDA, amount, token, account]
    );
}

exports.ConvertEncoder = ConvertEncoder;
