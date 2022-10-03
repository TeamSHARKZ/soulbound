// SPDX-License-Identifier: MIT

/**                                                               
 *******************************************************************************
 * Claim contract
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "../lib/sharkz/Adminable.sol";

interface IClaimable {
    function claimMint(address soulContract, uint256 soulTokenId) external;
}

interface IBalanceOf {
    function balanceOf(address owner) external view returns (uint256 balance);
}

interface IOwnerOf {
  function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract ClaimBadge is Adminable {
    IClaimable public targetContract;

    constructor () {}

    function setTarget (address _contract) external onlyAdmin {
        targetContract = IClaimable(_contract);
    }

    function claim(address soulContract, uint256 soulTokenId) 
        external 
        callerIsUser 
        callerIsSoulOwner(soulContract, soulTokenId)
    {
        require(targetContract != IClaimable(address(0)), 'Target contract is the zero address');
        targetContract.claimMint(soulContract, soulTokenId);
    }

    // Caller must not be an wallet account
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "Caller should not be a contract");
        _;
    }

    // Caller must be `Soul` token owner
    modifier callerIsSoulOwner(address soulContract, uint256 soulTokenId) {
        require(soulContract != address(0), "Soul contract is the zero address");

        address soulOwnerAddress;
        try IOwnerOf(soulContract).ownerOf(soulTokenId) returns (address ownerAddress) {
            if (ownerAddress != address(0)) {
                soulOwnerAddress = ownerAddress;
            }
        } catch (bytes memory) {}
        require(msg.sender == soulOwnerAddress && soulOwnerAddress != address(0), "Caller is not Soul token owner");
        _;
    }

    /**
     * @dev Returns whether an address is NFT owner
     */
    function _isExternalTokenOwner(address _contract, address _ownerAddress) internal view returns (bool) {
        try IBalanceOf(_contract).balanceOf(_ownerAddress) returns (uint256 balance) {
            return balance > 0;
        } catch (bytes memory) {
          // when reverted, just returns...
          return false;
        }
    }
}