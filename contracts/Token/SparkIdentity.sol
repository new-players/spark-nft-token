// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../Interfaces/IERC6551Manager.sol";
import "../Helpers/Validator.sol";

/// @custom:security-contact rvenki666@gmail.com
contract SparkIdentity is ERC721, AccessControl {
    error TokenTransferNotAllowed();

    uint256 private nextTokenId;
    string private baseURI;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    IERC6551Manager public erc6551ManagerContract;

    event SparkIdentityMinted(address indexed toAddress, uint256 sparkId);
    event SparkIdentityMintedForERC6551(
        address indexed tokenboundAddress,
        address indexed nftAddress,
        uint256 indexed nftTokenId,
        uint256 sparkId
    );

    constructor(
        string memory _name,
        string memory _symbol,
        address _admin
    ) ERC721(_name, _symbol) {
        Validator.checkForZeroAddress(_admin);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool isSupported) {
        isSupported = super.supportsInterface(interfaceId);
    }

    function configureERC6551Manager(
        address _erc6551ManagerContractAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Validator.checkForZeroAddress(_erc6551ManagerContractAddress);

        erc6551ManagerContract = IERC6551Manager(
            _erc6551ManagerContractAddress
        );
    }

    function setBaseURI(
        string calldata _baseUri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Validator.checkForZeroBytes(bytes(_baseUri));

        baseURI = _baseUri;
    }

    function safeMint(address _to) external onlyRole(MINTER_ROLE) {
        uint256 sparkId = _safeMint(_to);

        emit SparkIdentityMinted(_to, sparkId);
    }

    function safeMintERC6551(
        address _nftAddress,
        uint256 _nftTokenId
    ) external onlyRole(MINTER_ROLE) {
        address tokenboundAccountAddress = _createOrGetTokenboundAccountAddress(
            _nftAddress,
            _nftTokenId
        );
        uint256 sparkId = _safeMint(tokenboundAccountAddress);

        emit SparkIdentityMintedForERC6551(
            tokenboundAccountAddress,
            _nftAddress,
            _nftTokenId,
            sparkId
        );
    }

    function getTokenboundAccountAddress(
        address _nftAddress,
        uint256 _tokenId
    ) external view returns (address tokenboundAddress) {
        tokenboundAddress = erc6551ManagerContract.getTokenBoundAccount(
            _nftAddress,
            _tokenId
        );
    }

    function _safeMint(address _to) internal returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _safeMint(_to, tokenId);
    }

    function _createOrGetTokenboundAccountAddress(
        address _nftAddress,
        uint256 _tokenId
    ) internal returns (address tokenboundAddress) {
        tokenboundAddress = erc6551ManagerContract.createTokenBoundAccount(
            _nftAddress,
            _tokenId
        );
    }

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

    function _baseURI() internal view override returns (string memory baseUri) {
        baseUri = baseURI;
    }
}
