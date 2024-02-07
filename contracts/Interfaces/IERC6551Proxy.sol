// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Interface for ERC6551 Proxy
/// @notice This interface defines the standard functions and events for an ERC6551 Proxy contract.
interface IERC6551Proxy {
    /// @notice Error to indicate the contract has already been initialized.
    error AlreadyInitialized();

    /// @notice Error to indicate an invalid implementation address was provided.
    error InvalidImplementation();

    /// @notice Event emitted when the admin address is changed.
    /// @param previousAdmin The address of the previous admin.
    /// @param newAdmin The address of the new admin.
    event AdminChanged(address previousAdmin, address newAdmin);

    /// @notice Event emitted when the beacon contract is upgraded.
    /// @param beacon The address of the upgraded beacon.
    event BeaconUpgraded(address indexed beacon);

    /// @notice Event emitted when the implementation contract is upgraded.
    /// @param implementation The address of the upgraded implementation.
    event Upgraded(address indexed implementation);

    /// @notice Fallback function to allow the contract to receive ether.
    fallback() external payable;

    /// @notice Initializes the proxy contract with a given implementation.
    /// @param implementation The address of the implementation contract.
    function initialize(address implementation) external;

    /// @notice Function to allow the contract to receive ether without data.
    receive() external payable;
}