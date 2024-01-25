// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

library Validator {    
    error ZeroAddressNotAllowed();
    error InvalidBytes32();
    error InvalidBytes();
    error IncompatibleNFTContract();

    function checkForZeroAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert ZeroAddressNotAllowed();
        }
    }

    function checkForZeroBytes32(bytes32 value) internal pure {
        if (value.length == 0) {
            revert InvalidBytes32();
        }
    }

    function checkForZeroBytes(bytes memory value) internal pure {
        if (value.length == 0) {
            revert InvalidBytes();
        }
    }

    /// @notice Check for ERC165 compatibility
    /// @param _contractAddress contract address
    /// @param _interfaceId interface id of the contract
    function checkSupportsInterface(
        address _contractAddress,
        bytes4 _interfaceId
    ) internal view {
        bool isSupported = ERC165Checker.supportsInterface(
            _contractAddress,
            _interfaceId
        );

        if (!isSupported) {
            revert IncompatibleNFTContract();
        }
    }
}