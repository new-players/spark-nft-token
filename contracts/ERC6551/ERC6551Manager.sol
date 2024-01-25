// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../Helpers/Validator.sol";
import "../Interfaces/IERC6551Registry.sol";

/// @title ERC6551Manager contract
/// @author Venkatesh
/// @notice This contract is used to manage the ERC6551 funtionalities
contract ERC6551Manager is AccessControl {
    // Access control roles
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Use 0 bytes32 value as salt - It is officially used by tokenbound.orgs
    bytes32 public erc6551Salt;

    // check the implementation contracts from here => https://docs.tokenbound.org/contracts/deployments
    address public erc6551ImplementationAddress;

    // check the registry contracts from here => https://docs.tokenbound.org/contracts/deployments
    address public erc6551RegistryAddress;

    // ERC721 interface id to check the ERC721 compatibility
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

    event ERC6551RegistryUpdated(
        address oldRegistryAddress,
        address newRegistryAddress
    );
    event ERC6551SaltUpdated(bytes32 oldSalt, bytes32 newSalt);
    event ERC6551ImplementationUpdated(
        address oldImplementationAddress,
        address newImplementationAddress
    );

    constructor(
        address _registryAddress,
        address _implementationAddress,
        bytes32 _salt,
        address _owner
    ) {
        Validator.checkForZeroAddress(_registryAddress);
        Validator.checkForZeroAddress(_implementationAddress);
        Validator.checkForZeroAddress(_owner);
        Validator.checkForZeroBytes32(_salt);

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(MANAGER_ROLE, _owner);

        erc6551RegistryAddress = _registryAddress;
        erc6551ImplementationAddress = _implementationAddress;
        erc6551Salt = _salt;
    }

    /// @notice Configure the ERC 6551 registry contract address to lookup/create TBA
    /// @param _registryAddress ERC 6551 registry contract address
    function setupERC6551Registry(
        address _registryAddress
    ) external onlyRole(MANAGER_ROLE) {
        Validator.checkForZeroAddress(_registryAddress);

        address oldRegistryAddress = erc6551RegistryAddress;
        erc6551RegistryAddress = _registryAddress;

        emit ERC6551RegistryUpdated(oldRegistryAddress, erc6551RegistryAddress);
    }

    /// @notice Configure the ERC 6551 implementation contract address for TBA
    /// @param _implementationAddress ERC 6551 implementation contract address
    function setupERC6551Implementation(
        address _implementationAddress
    ) external onlyRole(MANAGER_ROLE) {
        Validator.checkForZeroAddress(_implementationAddress);

        address oldImplementationAddress = erc6551ImplementationAddress;
        erc6551ImplementationAddress = _implementationAddress;

        emit ERC6551ImplementationUpdated(
            oldImplementationAddress,
            erc6551ImplementationAddress
        );
    }

    /// @notice Configure the salt for the creation and lookup of token bound account
    /// @param _salt ERC 6551 salt value (zero is officially used)
    function setupERC6551Salt(bytes32 _salt) external onlyRole(MANAGER_ROLE) {
        Validator.checkForZeroBytes32(_salt);

        bytes32 oldSalt = erc6551Salt;
        erc6551Salt = _salt;

        emit ERC6551SaltUpdated(oldSalt, erc6551Salt);
    }

    /// @notice Determine or retrieve the NFT's token bound account address
    /// @param _nftContractAddress NFT contract address
    /// @param _tokenId NFT token ID
    /// @return tokenBoundAccountAddress NFT's token bound address
    function getTokenBoundAccount(
        address _nftContractAddress,
        uint256 _tokenId
    ) external view returns (address tokenBoundAccountAddress) {
        Validator.checkForZeroAddress(_nftContractAddress);
        Validator.checkSupportsInterface(
            _nftContractAddress,
            INTERFACE_ID_ERC721
        );

        IERC6551Registry _tokenboundRegistry = IERC6551Registry(
            erc6551RegistryAddress
        );

        tokenBoundAccountAddress = _tokenboundRegistry.account(
            erc6551ImplementationAddress,
            erc6551Salt,
            _getChainId(),
            _nftContractAddress,
            _tokenId
        );
    }

    /// @notice Deploy the NFT's token bound account address if it is not already deployed
    /// @param _nftContractAddress NFT contract address
    /// @param _tokenId NFT token ID
    /// @return tokenBoundAccountAddress NFT's token bound address
    function createTokenBoundAccount(
        address _nftContractAddress,
        uint256 _tokenId
    ) external returns (address tokenBoundAccountAddress) {
        Validator.checkForZeroAddress(_nftContractAddress);
        Validator.checkSupportsInterface(
            _nftContractAddress,
            INTERFACE_ID_ERC721
        );

        IERC6551Registry _tokenboundRegistry = IERC6551Registry(
            erc6551RegistryAddress
        );

        tokenBoundAccountAddress = _tokenboundRegistry.createAccount(
            erc6551ImplementationAddress,
            erc6551Salt,
            _getChainId(),
            _nftContractAddress,
            _tokenId
        );
    }

    /// @notice Retrieve the chain id of the network where the contract is deployed
    /// @return id chain id of the network
    function _getChainId() internal view virtual returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }
}
