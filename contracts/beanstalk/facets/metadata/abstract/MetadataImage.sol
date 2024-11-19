// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {C} from "contracts/C.sol";
import {AppStorage} from "contracts/beanstalk/storage/AppStorage.sol";
import {LibBytes64} from "contracts/libraries/LibBytes64.sol";
import {LibRedundantMath256} from "contracts/libraries/Math/LibRedundantMath256.sol";
import {LibBytes} from "contracts/libraries/LibBytes.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MetadataImage
 * @notice Contains image metadata for ERC1155 deposits.
 * @dev fully on-chain generated SVG.
 */

abstract contract MetadataImage {
    AppStorage internal s;

    using Strings for uint256;
    using Strings for int256;
    using LibRedundantMath256 for uint256;

    string constant LEAF_COLOR_0 = "#A8C83A";
    string constant LEAF_COLOR_1 = "#89A62F";
    uint256 constant NUM_PLOTS = 21;
    uint256 constant STALK_GROWTH = 2e8;

    function imageURI(address token, int96 stem) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    LibBytes64.encode(bytes(generateImage(token, stem)))
                )
            );
    }

    function generateImage(address token, int96 stem) internal view returns (string memory) {
        // Get deposit ID as uint256
        uint256 depositId = LibBytes.packAddressAndStem(token, stem);

        // Convert to hex string (will include '0x' prefix)
        string memory hexDepositId = Strings.toHexString(depositId, 32);

        // Get hash and convert to hex string
        bytes32 hash = keccak256(abi.encodePacked(hexDepositId));
        string memory hashString = Strings.toHexString(uint256(hash), 32);

        string memory truncatedId = string.concat(
            substring(hashString, 0, 8), // First 6 chars after '0x'
            "...",
            substring(hashString, bytes(hashString).length - 6, bytes(hashString).length) // Last 6 chars
        );

        // get the ERC20 name of the token
        string memory tokenText = ERC20(token).symbol();

        return
            string(
                abi.encodePacked(
                    '<svg width="478" height="266" viewBox="0 0 478 266" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><style>@import url(https://fonts.googleapis.com/css2?family=Inter:wght@500&amp;display=swap);</style></defs><rect width="478" height="266" rx="12" fill="url(#paint0_radial_2141_35163)"/><g filter="url(#filter0_i_2141_35163)"><text fill="#fff" xml:space="preserve" style="white-space:pre" font-family="Inter" font-size="16" font-weight="500" letter-spacing="0em"><tspan x="15" y="29.818">Deposit ',
                    truncatedId,
                    '</tspan></text></g><path d="M292.988 143.077c-1.153 2.554-3.291 3.447-5.801 3.447-5.333 0-9.753-2.121-13.128-6.411-.78-.992-1.285-2.145-1.417-3.435-.216-2.058.793-3.745 2.727-4.625 1.981-.905 4.059-.942 6.149-.583 3.183.546 6.017 1.91 8.443 4.142 1.37 1.252 2.355 2.777 3.039 4.513v2.952zm0-16.913c-.625 1.835-2.114 2.493-3.759 2.641-4.937.447-9.321-1.004-12.924-4.575-.636-.632-1.105-1.55-1.405-2.418-.408-1.178.072-2.22 1.105-2.988.937-.695 2.018-1.017 3.135-1.079 4.564-.273 8.599 1.103 12.034 4.241.865.793 1.406 1.81 1.826 2.901v1.277zm-54.096 42.804c-3.243.248-6.102-1.017-8.444-3.472-4.276-4.477-3.735-11.197 1.129-15.004 4.756-3.72 11.939-3.299 16.058.955 4.06 4.178 3.904 10.478-.348 14.483-2.27 2.145-4.684 3.025-8.383 3.025zm-29.51-6.458c-2.99-.025-5.212-.608-7.026-2.269-2.342-2.158-2.954-5.295-1.693-8.556 1.321-3.41 3.819-5.667 7.002-7.155 2.798-1.302 5.729-1.823 8.756-1.042 2.978.769 5.164 2.517 5.813 5.779.48 2.418-.204 4.625-1.538 6.596-2.894 4.254-6.918 6.374-11.314 6.647m58.892 0c2.99-.025 5.212-.608 7.026-2.269 2.342-2.158 2.955-5.295 1.694-8.556-1.322-3.41-3.82-5.667-7.003-7.155-2.798-1.302-5.729-1.823-8.755-1.042-2.979.769-5.165 2.517-5.814 5.779-.48 2.418.205 4.625 1.538 6.596 2.894 4.254 6.918 6.374 11.314 6.647m-28.049-16.854c-3.724 0-6.138-.583-8.264-2.108-1.933-1.389-3.219-3.199-3.062-5.779.132-2.132 1.273-3.658 2.894-4.836 2.57-1.872 5.477-2.492 8.588-2.207 2.066.199 3.999.819 5.741 2.021 4.18 2.902 4.204 7.887.048 10.801-2.138 1.5-4.54 2.083-5.933 2.083zm-49.292.955c-.636-.148-1.825-.285-2.906-.706-2.607-1.005-3.64-3.497-2.667-6.188.793-2.182 2.258-3.807 4.06-5.134 3.027-2.232 6.402-3.472 10.149-3.273a9.6 9.6 0 0 1 3.003.657c2.75 1.116 3.675 3.794 2.378 6.634-.661 1.438-1.61 2.629-2.787 3.646-3.099 2.678-6.642 4.154-11.242 4.352zm27.829-6.932c-2.511-.012-4.444-.384-6.186-1.488-2.63-1.661-3.243-4.588-1.501-7.204 1.249-1.885 3.027-3.063 5.056-3.844 3.279-1.265 6.606-1.525 9.921-.186 1.549.62 2.835 1.637 3.423 3.311.745 2.157-.072 3.943-1.489 5.468-1.85 1.997-4.192 3.075-6.774 3.609-.973.198-1.958.272-2.462.334zm41.089-.01c-3.015-.037-5.826-.83-8.252-2.678a10.2 10.2 0 0 1-2.354-2.505c-1.513-2.306-1.021-4.848 1.129-6.547 1.297-1.029 2.811-1.55 4.408-1.736 3.663-.434 7.074.322 10.125 2.53 1.009.731 1.862 1.624 2.462 2.752 1.297 2.443.721 4.911-1.501 6.498-1.586 1.128-3.711 1.724-6.005 1.686zm-62.131-21.825c1.357 0 2.678.162 3.903.819 1.718.917 2.21 2.455 1.309 4.228-.96 1.873-2.558 3.038-4.311 4.005-2.451 1.364-5.081 2.133-7.879 2.208-1.61.049-3.183-.137-4.54-1.191-.937-.731-1.273-1.785-.973-2.951.42-1.587 1.453-2.716 2.678-3.658 2.895-2.232 6.186-3.348 9.789-3.472zm68.124 9.038c-3.207-.124-6.209-.806-8.768-2.815-.78-.607-1.465-1.463-1.957-2.331-.781-1.376-.421-2.802.756-3.844 1.189-1.054 2.643-1.513 4.156-1.674 3.471-.384 6.762.273 9.717 2.257a9.1 9.1 0 0 1 2.306 2.269c1.201 1.724.78 3.559-.913 4.762-1.141.806-2.438 1.128-3.783 1.289-.517.062-1.033.062-1.502.087zm-53.544.137c-1.525.025-3.015-.161-4.408-.843-.564-.285-1.129-.645-1.573-1.104-1.273-1.302-1.189-3.137.108-4.724 1.093-1.339 2.498-2.22 4.048-2.864 3.014-1.24 6.113-1.637 9.272-.72a7.3 7.3 0 0 1 2.162 1.067c1.657 1.178 1.957 2.951.816 4.675-1.153 1.748-2.87 2.728-4.732 3.459a15.2 15.2 0 0 1-5.693 1.067zm41.233-19.58c2.678.049 4.972.446 7.05 1.661.745.434 1.465.992 2.018 1.65 1.093 1.289.864 2.728-.481 3.744-1.009.769-2.174 1.141-3.387 1.327-3.327.509-6.51.062-9.488-1.612-.625-.347-1.201-.843-1.682-1.389-1.117-1.289-.912-2.79.433-3.819 1.093-.831 2.354-1.215 3.675-1.413.721-.1 1.441-.137 1.85-.174zm-31.012 8.609c-2.378-.037-3.963-.236-5.464-.918-2.667-1.227-2.931-3.484-.625-5.307 1.597-1.265 3.471-1.86 5.429-2.17 2.234-.347 4.456-.335 6.606.484.684.26 1.357.657 1.921 1.128 1.141.992 1.177 2.369.205 3.559-1.153 1.389-2.715 2.096-4.36 2.53-1.454.384-2.955.558-3.712.694m48.679-9.599c3.111.087 6.077.744 8.66 2.617.708.508 1.321 1.227 1.801 1.971.613.955.373 2.096-.6 2.666-.805.471-1.73.881-2.643.98-4.071.471-7.843-.409-11.182-2.939-.432-.335-.804-.806-1.105-1.277-.684-1.079-.456-2.158.565-2.902 1.069-.793 2.306-.979 3.567-1.103.312-.025.625 0 .925 0zm-64.256.16c1.441 0 2.846.149 4.131.893 1.442.843 1.706 2.108.721 3.472-.228.323-.517.62-.805.881-1.429 1.252-3.123 1.984-4.9 2.48-2.414.682-4.864 1.004-7.339.334a5.6 5.6 0 0 1-1.681-.768c-.925-.633-1.129-1.612-.637-2.642.469-.992 1.273-1.661 2.15-2.244 2.234-1.488 5.429-2.393 8.36-2.393zm31.611 5.482c-1.838-.173-3.627-.421-5.273-1.302-.504-.272-.997-.607-1.405-1.016-.997-.992-.985-2.183-.036-3.224.901-.968 2.054-1.488 3.291-1.811 3.303-.868 6.546-.781 9.669.719.444.211.864.509 1.225.844 1.309 1.202 1.261 2.666-.12 3.794-1.202.98-2.619 1.438-4.096 1.674-1.081.174-2.174.223-3.267.322zm-19.997-5.903c-1.009 0-2.39-.112-3.699-.645a6 6 0 0 1-.733-.347c-1.441-.844-1.585-2.183-.336-3.324 1.213-1.103 2.69-1.649 4.227-2.02 2.475-.584 4.949-.708 7.411.061a5.6 5.6 0 0 1 1.597.806c1.021.732 1.177 1.86.253 2.716-.769.707-1.706 1.277-2.655 1.699-1.801.793-3.735 1.054-6.077 1.054zm40.632-.027c-2.378-.012-4.696-.409-6.822-1.55a6.2 6.2 0 0 1-1.609-1.277c-.757-.843-.649-1.761.192-2.517.889-.806 2.006-1.104 3.123-1.265 2.93-.434 5.789-.124 8.479 1.141.781.372 1.526.955 2.126 1.6.829.88.649 1.909-.324 2.628-1.249.918-2.703 1.104-4.168 1.24-.324.025-.661 0-.997 0M239.132 97c1.898.05 3.808.26 5.549 1.215.793.434 1.598.918 1.586 2.009 0 1.054-.805 1.538-1.598 1.934-2.066 1.042-4.276 1.228-6.522 1.129-1.489-.075-2.966-.273-4.335-.943a6.3 6.3 0 0 1-1.562-1.103c-.564-.533-.624-1.401-.084-1.947a6.8 6.8 0 0 1 1.85-1.327c1.597-.769 3.339-.917 5.116-.955z" fill="#F8F8F8"/><g filter="url(#filter1_i_2141_35163)"><text fill="#fff" xml:space="preserve" style="white-space:pre" font-family="Inter" font-size="16" font-weight="500" letter-spacing="0em" text-anchor="end"><tspan x="460" y="247.818">',
                    tokenText,
                    '</tspan></text></g><defs><filter id="filter0_i_2141_35163" x="16.278" y="17.898" width="214.464" height="19.375" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feFlood flood-opacity="0" result="BackgroundImageFix"/><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/><feOffset dy="4"/><feGaussianBlur stdDeviation="2"/><feComposite in2="hardAlpha" operator="arithmetic" k2="-1" k3="1"/><feColorMatrix values="0 0 0 0 0.480811 0 0 0 0 0.480811 0 0 0 0 0.480811 0 0 0 0.2 0"/><feBlend in2="shape" result="effect1_innerShadow_2141_35163"/></filter><filter id="filter1_i_2141_35163" x="15" y="236.203" width="448" height="15.957" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feFlood flood-opacity="0" result="BackgroundImageFix"/><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/><feOffset dy="4"/><feGaussianBlur stdDeviation="2"/><feComposite in2="hardAlpha" operator="arithmetic" k2="-1" k3="1"/><feColorMatrix values="0 0 0 0 0.480811 0 0 0 0 0.480811 0 0 0 0 0.480811 0 0 0 0.2 0"/><feBlend in2="shape" result="effect1_innerShadow_2141_35163"/></filter><radialGradient id="paint0_radial_2141_35163" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0 271.224 -487.387 0 239.722 0)"><stop offset=".128" stop-color="#88C4A6"/><stop offset=".297" stop-color="#68AD8B"/><stop offset=".461" stop-color="#45906A"/><stop offset=".64" stop-color="#387F5C"/><stop offset=".841" stop-color="#246645"/></radialGradient></defs></svg>'
                )
            );
    }

    function substring(
        string memory str,
        uint startIndex,
        uint endIndex
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function getTokenName(address token) internal view returns (string memory tokenString) {
        tokenString = ERC20(token).symbol();
    }
}
