// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "../Helpers/Validator.sol";

/// @title Spark Identity contract
/// @author Venkatesh
/// @notice This contract is used to manage spark identity for spark services
/// @dev Implementation of an ERC721 token with role-based permission controls that integrates with ERC6551 for token-bound accounts.
/// @custom:security-contact rvenki666@gmail.com
contract SparkIdentity is ERC721, AccessControlEnumerable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private nextTokenId;
    string public baseURI;

    /// @dev Error thrown when a token transfer is attempted but not allowed
    error TokenTransferNotAllowed();

    /// @dev Error thrown when more than one NFT is attempted to be minted for an address
    error MoreThanOneNftNotAllowed();

    /// @notice Constructor to create SparkIdentity contract
    /// @param _name The name of the ERC721 token
    /// @param _symbol The symbol of the ERC721 token
    /// @param _admin The address to be granted the admin role
    constructor(
        string memory _name,
        string memory _symbol,
        address _admin
    ) ERC721(_name, _symbol) {
        Validator.checkForZeroAddress(_admin);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
    }

    /// @notice Checks if the contract supports a given interface
    /// @dev Overrides the supportsInterface function of ERC721 and AccessControlEnumerable
    /// @param _interfaceId The interface identifier, as specified in ERC-165
    /// @return isSupported True if the contract supports the interface
    function supportsInterface(
        bytes4 _interfaceId
    ) public view override(ERC721, AccessControlEnumerable) returns (bool isSupported) {
        isSupported = super.supportsInterface(_interfaceId);
    }

    /// @notice Sets the base URI for computing {tokenURI}
    /// @dev Can only be called by an account with the DEFAULT_ADMIN_ROLE
    /// @param _baseUri The base URI to be set
    function setBaseURI(
        string calldata _baseUri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Validator.checkForZeroBytes(bytes(_baseUri));

        baseURI = _baseUri;
    }

    /// @notice Safely mints a new Spark Identity and assigns it to an address
    /// @dev Can only be called by an account with the MINTER_ROLE
    /// @param _to The address to mint the Spark Identity to
    function safeMint(address _to) external onlyRole(MINTER_ROLE) returns (uint256 sparkId) {
        if (_checkExistingMint(_to)) {
            revert MoreThanOneNftNotAllowed();
        }

        sparkId = nextTokenId++;
        _safeMint(_to, sparkId);
    }

    /// @dev Internal function to check if an address has already minted a Spark Identity
    /// @param _address The address to check
    /// @return nftStatus True if the address has already minted a Spark Identity
    function _checkExistingMint(
        address _address
    ) internal view returns (bool nftStatus) {
        nftStatus = balanceOf(_address) != 0;
    }

    /// @dev Internal function to update the ownership of a Spark Identity
    /// @param _to The address to transfer the Spark Identity to
    /// @param _tokenId The ID of the Spark Identity
    /// @param _auth The address authorized to make the transfer
    /// @return from The previous owner of the Spark Identity
    function _update(
        address _to,
        uint256 _tokenId,
        address _auth
    ) internal override returns (address from) {
        from = _ownerOf(_tokenId);

        if (from != address(0) && _to != address(0)) {
            revert TokenTransferNotAllowed();
        }

        from = super._update(_to, _tokenId, _auth);
    }

    /// @dev Internal function to return the base URI for computing {tokenURI}
    /// @return baseUri The base URI set for the contract
    function _baseURI() internal view override returns (string memory baseUri) {
        baseUri = baseURI;
    }
}
