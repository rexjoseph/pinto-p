// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TestHelper, LibTransfer, IMockFBeanstalk, C} from "test/foundry/utils/TestHelper.sol";
import {MetadataImage} from "contracts/beanstalk/facets/metadata/abstract/MetadataImage.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console.sol";

contract MetadataImageTest is TestHelper {
    MetadataImage metadataImage;

    function setUp() public {
        initializeBeanstalkTestState(true, false);

        // Deploy MetadataImage contract
        metadataImage = MetadataImage(address(new MetadataImageHarness()));
    }

    function testGenerateAndSaveSVG() public {
        generateAndSaveSVG(BEAN, 1000);
        generateAndSaveSVG(BEAN_WSTETH_WELL, -1001);
    }

    function generateAndSaveSVG(address token, int96 stem) public {
        // Generate SVG
        string memory svgData = metadataImage.imageURI(token, stem);

        // Remove the data:image/svg+xml;base64, prefix
        string memory base64Data = substring(svgData, 26, bytes(svgData).length);

        // Decode base64 to get raw SVG
        string memory svg = string(abi.encodePacked(decode(base64Data)));

        // Write to file
        vm.writeFile(
            string.concat(
                "test/generated/generated_",
                Strings.toHexString(uint160(token), 20),
                ".svg"
            ),
            svg
        );
    }

    function substring(
        string memory str,
        uint startIndex,
        uint endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    // this base64 decode function is from Solady
    // https://github.com/Vectorized/solady/blob/8d868a936ec1a45be294e26de1a64ebfb73c6c20/src/utils/Base64.sol
    // License for this function: MIT
    // It's only used for testing purposes, no deployed contract code uses base64 decode.
    function decode(string memory data) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let dataLength := mload(data)

            if dataLength {
                let decodedLength := mul(shr(2, dataLength), 3)

                for {} 1 {} {
                    // If padded.
                    if iszero(and(dataLength, 3)) {
                        let t := xor(mload(add(data, dataLength)), 0x3d3d)
                        // forgefmt: disable-next-item
                        decodedLength := sub(
                            decodedLength,
                            add(iszero(byte(30, t)), iszero(byte(31, t)))
                        )
                        break
                    }
                    // If non-padded.
                    decodedLength := add(decodedLength, sub(and(dataLength, 3), 1))
                    break
                }
                result := mload(0x40)

                // Write the length of the bytes.
                mstore(result, decodedLength)

                // Skip the first slot, which stores the length.
                let ptr := add(result, 0x20)
                let end := add(ptr, decodedLength)

                // Load the table into the scratch space.
                // Constants are optimized for smaller bytecode with zero gas overhead.
                // `m` also doubles as the mask of the upper 6 bits.
                let m := 0xfc000000fc00686c7074787c8084888c9094989ca0a4a8acb0b4b8bcc0c4c8cc
                mstore(0x5b, m)
                mstore(0x3b, 0x04080c1014181c2024282c3034383c4044484c5054585c6064)
                mstore(0x1a, 0xf8fcf800fcd0d4d8dce0e4e8ecf0f4)

                for {} 1 {} {
                    // Read 4 bytes.
                    data := add(data, 4)
                    let input := mload(data)

                    // Write 3 bytes.
                    // forgefmt: disable-next-item
                    mstore(
                        ptr,
                        or(
                            and(m, mload(byte(28, input))),
                            shr(
                                6,
                                or(
                                    and(m, mload(byte(29, input))),
                                    shr(
                                        6,
                                        or(
                                            and(m, mload(byte(30, input))),
                                            shr(6, mload(byte(31, input)))
                                        )
                                    )
                                )
                            )
                        )
                    )
                    ptr := add(ptr, 3)
                    if iszero(lt(ptr, end)) {
                        break
                    }
                }
                mstore(0x40, add(end, 0x20)) // Allocate the memory.
                mstore(end, 0) // Zeroize the slot after the bytes.
                mstore(0x60, 0) // Restore the zero slot.
            }
        }
    }
}

// Harness contract to make MetadataImage deployable
contract MetadataImageHarness is MetadataImage {
    constructor() {}
}
