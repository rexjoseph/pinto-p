const fs = require("fs");

function commentOutOracleTimeout(solidityFilePath) {
  let fileContent = fs.readFileSync(solidityFilePath, "utf8");
  // Define the regex patterns to comment out specific lines
  const timestampCheckRegex =
    /if\s*\(timestamp\s*==\s*0\s*\|\|\s*timestamp\s*>\s*currentTimestamp\s*\)\s*return\s*true\s*;/;
  const timeoutCheckRegex =
    /if\s*\(currentTimestamp\.sub\(timestamp\)\s*>\s*maxTimeout\s*\)\s*return\s*true\s*;/;
  const answerCheckRegex = /if\s*\(answer\s*<=\s*0\s*\)\s*return\s*true\s*;/;
  const returnFalseRegex = /return\s*false\s*;/;

  // Replace the lines with commented versions
  fileContent = fileContent.replace(
    timestampCheckRegex,
    "// " + fileContent.match(timestampCheckRegex)[0]
  );
  fileContent = fileContent.replace(
    timeoutCheckRegex,
    "// " + fileContent.match(timeoutCheckRegex)[0]
  );
  fileContent = fileContent.replace(
    answerCheckRegex,
    "// " + fileContent.match(answerCheckRegex)[0]
  );
  fileContent = fileContent.replace(
    returnFalseRegex,
    "// " + fileContent.match(returnFalseRegex)[0]
  );
  fs.writeFileSync(solidityFilePath, fileContent, "utf8");
  console.log("Commented out specific checks in checkForInvalidTimestampOrAnswer function.");
}

function uncommentOracleTimeout(solidityFilePath) {
  let fileContent = fs.readFileSync(solidityFilePath, "utf8");

  // Define the regex patterns to uncomment specific lines
  const timestampCheckRegex =
    /\/\/\s*if\s*\(timestamp\s*==\s*0\s*\|\|\s*timestamp\s*>\s*currentTimestamp\s*\)\s*return\s*true\s*;/;
  const timeoutCheckRegex =
    /\/\/\s*if\s*\(currentTimestamp\.sub\(timestamp\)\s*>\s*maxTimeout\s*\)\s*return\s*true\s*;/;
  const answerCheckRegex = /\/\/\s*if\s*\(answer\s*<=\s*0\s*\)\s*return\s*true\s*;/;
  const returnFalseRegex = /\/\/\s*return\s*false\s*;/;

  // Uncomment the lines by removing the comment prefix
  fileContent = fileContent.replace(timestampCheckRegex, (match) => match.slice(3));
  fileContent = fileContent.replace(timeoutCheckRegex, (match) => match.slice(3));
  fileContent = fileContent.replace(answerCheckRegex, (match) => match.slice(3));
  fileContent = fileContent.replace(returnFalseRegex, (match) => match.slice(3));

  // Write the uncommented content back to the file
  fs.writeFileSync(solidityFilePath, fileContent, "utf8");
  console.log("Uncommented specific checks in checkForInvalidTimestampOrAnswer function.");
}

exports.commentOutOracleTimeout = commentOutOracleTimeout;
exports.uncommentOracleTimeout = uncommentOracleTimeout;
