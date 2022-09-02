// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * IERC4973 Soul Container interface
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./IERC4973.sol";

/**
 * @dev See https://eips.ethereum.org/EIPS/eip-4973
 * This is additional interface on top of EIP-4973
 */
interface IERC4973SoulContainer is IERC165, IERC4973 {
  /**
   * @dev This emits when any guardian added or removed for a token.
   */
  event SetGuardian(address indexed to, uint256 indexed tokenId, bool approved);

  /**
   * @dev This emits when token owner or guardian request for token renewal.
   */
  event RequestRenew(address indexed from, uint256 indexed tokenId, uint256 expireTimestamp);

  /**
   * @dev This emits when renewal request approved by one address
   */
  event ApproveRenew(uint256 indexed tokenId, bool indexed approved);

  /**
   * @dev This emits when a token is renewed and bind to new address
   */
  event Renew(address indexed to, uint256 indexed tokenId);
  
  /**
   * @dev Returns token id for the address (since it is 1:1 mapping of token and address)
   */
  function tokenIdOf(address owner) external view returns (uint256);

  /**
   * @dev Returns whether an address is guardian of `tokenId`.
   */
  function isGuardian(address addr, uint256 tokenId) external view returns (bool);

  /**
   * @dev Set/remove guardian for `tokenId`.
   *
   * Requirements:
   * - `tokenId` exists
   * - (addition) guardian is not set before
   * - (removal) guardian should be existed
   *
   * Access:
   * - `tokenId` owner
   * 
   * Emits {SetGuardian} event.
   */
  function setGuardian(address to, bool approved, uint256 tokenId) external;

  /**
   * @dev Request for token renewal for token owner or other token as guardian, requester 
   * can then re-assign token to a new address.
   * It is recommanded to setup non-zero expiry timestamp, zero expiry means the 
   * request can last forever to get approvals.
   *
   * Requirements:
   * - `tokenId` exists
   *
   * Access:
   * - `tokenId` owner
   * - `tokenId` guardian
   *
   * Emits {RequestRenew} event.
   */
  function requestRenew(uint256 expireTimestamp, uint256 tokenId) external;

  /**
   * @dev Approve or cancel approval for a renewal request.
   * Owner or guardian can reset the renewal request by calling requestRenew() again to 
   * reset request approver index key to new value.
   *
   * Valid approvers = N = 1 + guardians (1 from token owner)
   * Mininum one guardian is needed to build the quorum system.
   *
   * Approval quorum (> 50%) = N / 2 + 1
   * For example: 3 approvers = 2 quorum needed
   *              4 approvers = 3 quorum needed
   *              5 approvers = 3 quorum needed
   *
   * Requirements:
   * - `tokenId` exists
   * - request not expired
   *
   * Access:
   * - `tokenId` owner
   * - `tokenId` guardian
   *
   * Emits {ApproveRenew} event.
   */
  function approveRenew(bool approved, uint256 tokenId) external;

  /**
   * @dev Renew a token to new address.
   *
   * Renewal process (token can be renewed and bound to new address):
   * 1) Token owner or guardians (in case of the owner lost wallet) create/reset a renewal request
   * 2) Token owner and eacg guardian can approve the request until approval quorum (> 50%) reached
   * 3) Renewal action can be called by request originator to set the new binding address
   *
   * Requirements:
   * - `tokenId` exists
   * - request not expired
   * - request approved
   * - `to` address is not an owner of another token
   * - `to` cannot be the zero address.
   *
   * Access:
   * - `tokenId` owner
   * - `tokenId` guardian
   * - requester of the request
   *
   * Emits {Renew} event.
   */
  function renew(address to, uint256 tokenId) external;
}