// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISparkIdentity {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    function setApprovalForAll(address operator, bool approved) external;

    function balanceOf(address owner) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) external;

    function safeMint(address _to) external returns (uint256 sparkId);

    function setBaseURI(string calldata _baseUri) external;

    function supportsInterface(
        bytes4 interfaceId
    ) external view returns (bool isSupported);
}
