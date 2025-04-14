// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./IERC4907.sol";
import "../ERC721AStruct.sol";

abstract contract ERC4907 is ERC721AStruct, IERC4907 {
    // Compiler will pack this into a single 256bit word.
    struct UserInfo {
        address user; // address of user role
        uint64 expires; // unix timestamp, user expires
    }

    mapping (uint256 => UserInfo) internal _users;

    /**
     * @dev Set the user and expires of `tokenId`. See {IERC4907-setUser}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function setUser(uint256 tokenId, address user, uint64 expires) external virtual override {
        address ownerAddr = _ownershipOf(tokenId).addr;
        bool isApprovedOrOwner = (_msgSenderERC721A() == ownerAddr ||
            isApprovedForAll(ownerAddr, _msgSenderERC721A()) ||
            getApproved(tokenId) == _msgSenderERC721A());
        require (isApprovedOrOwner, "ERC4907: transfer caller is not owner nor approved");

        UserInfo storage info = _users[tokenId];
        info.user = user;
        info.expires = expires;

        emit UpdateUser(tokenId, user, expires);
    }

    /**
     * @dev Returns the user address for `tokenId`.
     * The zero address indicates that there is no user or if the user is expired.
     */
    function userOf(uint256 tokenId) external view virtual override returns (address) {
        if (uint256(_users[tokenId].expires) >= block.timestamp){
            return _users[tokenId].user;
        } else {
            return address(0);
        }
    }

    /**
     * @dev Returns the user's expires timestamp of `tokenId`. 
     * The zero value indicates that there is no user.
     */
    function userExpires(uint256 tokenId) external view virtual override returns (uint256) {
        return _users[tokenId].expires;
    }

    /**
     * @dev Clear the user info (on transfer, burn) for `tokenId`.
     *
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);

        // ERC721 transfer or burn should only affect one token at a time
        if (quantity == 1) {
            uint256 tokenId = startTokenId;
            if (from != to && _users[tokenId].user != address(0)) {
                // clear user info
                delete _users[tokenId];
                emit UpdateUser(tokenId, address(0), 0);
            }
        }
    }

    /**
     * @dev Override of {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        // The interface ID for ERC4907 is `0xad092b5c`,
        // as defined in [ERC4907](https://eips.ethereum.org/EIPS/eip-4907).
        return super.supportsInterface(interfaceId) || interfaceId == 0xad092b5c;
    }
}