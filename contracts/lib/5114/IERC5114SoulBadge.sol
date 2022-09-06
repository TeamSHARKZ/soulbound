// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * IERC5114 Soul Badge interface
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./IERC5114.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

/**
 * @dev See https://eips.ethereum.org/EIPS/eip-5114
 * This is additional interface on top of EIP-5114
 *
 * (bytes4) 0xb9d11845 = type(IERC5114SoulBadge).interfaceId
 */
interface IERC5114SoulBadge is IERC165, IERC721Metadata, IERC5114 {
  // Returns badge token balance for a `Soul`
  function balanceOfSoul(address soulContract, uint256 soulTokenId) external view returns (uint256);

  // Returns the `Soul` token owner address
  function soulOwnerOf(uint256 tokenId) external view returns (address);
}