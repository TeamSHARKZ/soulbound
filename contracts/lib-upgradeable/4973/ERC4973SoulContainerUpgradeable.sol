// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * ERC4973 Soul Container
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "../../lib/4973/IERC4973SoulContainer.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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
 * @dev See https://eips.ethereum.org/EIPS/eip-4973
 * @dev Implementation of IERC4973 and the additional IERC4973 Soul Container interface
 * 
 * Please noted that EIP-4973 is a draft proposal by the time of contract design, EIP 
 * final definition can be changed.
 * 
 * This implementation included many features for real-life usage, by including ERC721
 * Metadata extension, we allow NFT platforms to recognize the token name, symbol and token
 * metadata, ex. token image, attributes. By design, ERC721 transfer, operator, and approval 
 * mechanisms are all removed.
 *
 * Access controls applied user roles: token owner, token guardians, admins, public users.
 * 
 * Assumes that the max value for token ID, and guardians numbers are 2**256 (uint256).
 *
 */
contract ERC4973SoulContainerUpgradeable is IERC721Metadata, IERC4973SoulContainer, Initializable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     * It is required for NFT platforms to detect token creation.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Token ID and address is 1:1 binding, however, existing token can be renewed or burnt, 
     * releasing old address to be bind to new token ID.
     *
     * Compiler will pack this into a single 256bit word.
     */
    struct AddressData {
        // address token ID
        uint256 tokenId;
        // We use smallest uint8 to record 0 or 1 value
        uint8 balance;
        // Token creation time for the only token for the address
        uint40 createTimestamp;
        // Keep track of historical minted token amount
        uint64 numberMinted;
        // Keep track of historical burnt token amount
        uint64 numberBurned;
        // Keep track of renewal counter for address
        uint80 numberRenewal;
    }

    // Mapping address to address token data
    mapping(address => AddressData) internal _addressData;

    // Renewal request struct
    struct RenewalRequest {
        // Requester address can be token owner or guardians
        address requester;
        // Request created time
        uint40 createTimestamp;
        // Request expiry time
        uint40 expireTimestamp;
        // uint16 leaveover in uint256 struct
    }

    // Mapping token ID to renewal request, only store last request to allow easy override
    mapping(uint256 => RenewalRequest) private _renewalRequest;

    // Mapping request hash key to approver addresses
    mapping(uint256 => mapping(address => bool)) private _renewalApprovers;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping token ID to multiple guardians.
    mapping(uint256 => address[]) private _guardians;

    function __ERC4973SoulContainer_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC4973SoulContainer_init_unchained(name_, symbol_);
    }

    function __ERC4973SoulContainer_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        // See: https://eips.ethereum.org/EIPS/eip-165
        // return true to show proof of supporting following interface, we use bytes4 
        // interface id to avoid importing the whole interface codes.
        return
            interfaceId == 0x01ffc9a7 || // ERC165 interface ID for ERC165.
            interfaceId == 0x5b5e139f || // ERC165 interface ID for ERC721Metadata.
            interfaceId == type(IERC4973).interfaceId ||
            interfaceId == type(IERC4973SoulContainer).interfaceId;
    }

    /**
     * @dev See {IERC4973-tokenIdOf}.
     */
    function tokenIdOf(address owner) public view virtual override returns (uint256) {
        require(balanceOf(owner) > 0, "ERC4973SoulContainer: token id query for non-existent owner");
        return uint256(_addressData[owner].tokenId);
    }

    /**
     * @dev See {IERC4973-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC4973SoulContainer: balance query for the zero address");
        return uint256(_addressData[owner].balance);
    }

    // Returns owner address of a token ID
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev See {IERC4973-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC4973SoulContainer: owner query for non-existent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation with `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) external view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for non-existent token");
        return bytes(_baseURI()).length != 0 ? string(abi.encodePacked(_baseURI(), _toString(tokenId))) : "";
    }

    // Returns whether `tokenId` exists.
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    // Returns whether the address is either the owner or guardian
    function _isOwnerOrGuardian(address addr, uint256 tokenId) internal view virtual returns (bool) {
        return (addr != address(0) && (addr == _ownerOf(tokenId) || _isGuardian(addr, tokenId)));
    }

    // Returns guardian index by address for the token
    function _getGuardianIndex(address addr, uint256 tokenId) internal view virtual returns (uint256) {
        for (uint256 i = 0; i < _guardians[tokenId].length; i++) {
            if (addr == _guardians[tokenId][i]) {
                return i;
            }
        }
        revert("ERC4973SoulContainer: guardian index error");
    }

    // Returns guardian address by index
    function getGuardianByIndex(uint256 index, uint256 tokenId) external view virtual returns (address) {
        require(_isOwnerOrGuardian(_msgSenderERC4973(), tokenId), "ERC4973SoulContainer: query from non-owner or guardian");
        return _guardians[tokenId][index];
    }

    // Returns guardian count
    function getGuardianCount(uint256 tokenId) external view virtual returns (uint256) {
        require(_isOwnerOrGuardian(_msgSenderERC4973(), tokenId), "ERC4973SoulContainer: query from non-owner or guardian");
        return _guardians[tokenId].length;
    }

    // Returns whether an address is token guardian
    function _isGuardian(address addr, uint256 tokenId) internal view virtual returns (bool) {
        // we assumpt that each token ID should not contains too many guardians
        for (uint256 i = 0; i < _guardians[tokenId].length; i++) {
            if (addr == _guardians[tokenId][i]) {
                return true;
            }
        }
        return false;
    }

    // Remove existing guardian
    function _removeGuardian(address addr, uint256 tokenId) internal virtual {
        uint256 total = _guardians[tokenId].length;
        if (_guardians[tokenId][total-1] != addr) {
            uint256 index = _getGuardianIndex(addr, tokenId);
            // replace current value from last array element
            _guardians[tokenId][index] = _guardians[tokenId][total-1];
            // remove last element and shorten the array length
            _guardians[tokenId].pop();
        } else {
            // remove last element and shorten the array length
            _guardians[tokenId].pop();
        }
    }

    /**
     * @dev See {IERC4973SoulId-isGuardian}.
     */
    function isGuardian(address addr, uint256 tokenId) external view virtual override returns (bool) {
        require(addr != address(0), "ERC4973SoulContainer: guardian is zero address");
        return _isGuardian(addr, tokenId);
    }

    /**
     * @dev See {IERC4973SoulId-setGuardian}.
     */
    function setGuardian(address to, bool approved, uint256 tokenId) external virtual override {
        // access controls
        require(ownerOf(tokenId) == _msgSenderERC4973(), "ERC4973SoulContainer: guardian setup query from non-owner");
        
        // requirements
        require(to != address(0), "ERC4973SoulContainer: guardian setup query for the zero address");
        require(_exists(tokenId), "ERC4973SoulContainer: guardian setup query for non-existent token");
        if (approved) {
            // adding guardian
            require(!_isGuardian(to, tokenId) && to != _ownerOf(tokenId), "ERC4973SoulContainer: guardian already existed");
            _guardians[tokenId].push(to);

        } else {
            // remove guardian
            require(_isGuardian(to, tokenId), "ERC4973SoulContainer: removing non-existent guardian");
            _removeGuardian(to, tokenId);
        }

        emit SetGuardian(to, tokenId, approved);
    }

    // Returns approver unique hashed key for last token renewal request
    function _approverIndexKey(uint256 tokenId) internal view virtual returns (uint256) {
        uint256 createTime = _renewalRequest[tokenId].createTimestamp;
        return uint256(keccak256(abi.encodePacked(createTime, ":", tokenId)));
    }

    // Returns approval count for the renewal request (approvers can be token owner or guardians)
    function getApprovalCount(uint256 tokenId) public view virtual returns (uint256) {
        uint256 indexKey = _approverIndexKey(tokenId);
        uint256 count = 0;

        // count if token owner approved
        if (_renewalApprovers[indexKey][ownerOf(tokenId)]) {
            count += 1;
        }

        for (uint256 i = 0; i < _guardians[tokenId].length; i++) {
            address guardian = _guardians[tokenId][i];
            if (_renewalApprovers[indexKey][guardian]) {
                count += 1;
            }
        }

        return count;
    }

    // Returns request approval quorum size (min number of approval needed)
    function getApprovalQuorum(uint256 tokenId) public view virtual returns (uint256) {
        uint256 guardianCount = _guardians[tokenId].length;
        // mininum approvers are 2 (can be 1 token owner plus at least 1 guardian)
        require(guardianCount > 0, "ERC4973SoulContainer: approval quorum require at least one guardian");

        uint256 total = 1 + guardianCount;
        uint256 quorum = (total) / 2 + 1;
        return quorum;
    }

    /**
     * Returns whether renew request approved
     *
     * Valid approvers = N = 1 + guardians (1 from token owner)
     * Mininum one guardian is needed to build the quorum system.
     *
     * Approval quorum = N / 2 + 1
     * For example: 3 approvers = 2 quorum needed
     *              4 approvers = 3 quorum needed
     *              5 approvers = 3 quorum needed
     *
     * Requirements:
     * - renewal request is not expired
     */
    function isRequestApproved(uint256 tokenId) public view virtual returns (bool) {
        if (getApprovalCount(tokenId) >= getApprovalQuorum(tokenId)) {
          return true;
        } else {
          return false;
        }
    }

    // Returns whether renew request is expired
    function isRequestExpired(uint256 tokenId) public view virtual returns (bool) {
        uint256 expiry = uint256(_renewalRequest[tokenId].expireTimestamp);
        if (expiry > 0 && expiry <= block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev See {IERC4973SoulId-requestRenew}.
     */
    function requestRenew(uint256 expireTimestamp, uint256 tokenId) external virtual override {
        // access controls
        require(_isOwnerOrGuardian(_msgSenderERC4973(), tokenId), "ERC4973SoulContainer: query from non-owner or guardian");

        // requirements
        // minimum 2 approvers: approver #1 is owner, approver #2, #3... are guardians
        require(_guardians[tokenId].length > 0, "ERC4973SoulContainer: approval quorum require at least one guardian");

        _renewalRequest[tokenId].requester = _msgSenderERC4973();
        _renewalRequest[tokenId].expireTimestamp = uint40(expireTimestamp);
        _renewalRequest[tokenId].createTimestamp = uint40(block.timestamp);

        // requester should auto approve the request
        _renewalApprovers[_approverIndexKey(tokenId)][_msgSenderERC4973()] = true;

        emit RequestRenew(_msgSenderERC4973(), tokenId, expireTimestamp);
    }

    /**
     * @dev See {IERC4973SoulId-approveRenew}.
     */
    function approveRenew(bool approved, uint256 tokenId) external virtual override {
        // access controls
        require(_isOwnerOrGuardian(_msgSenderERC4973(), tokenId), "ERC4973SoulContainer: query from non-owner or guardian");

        // requirements
        require(!isRequestExpired(tokenId), "ERC4973SoulContainer: request expired");
        // minimum 2 approvers: approver #1 is owner, approver #2, #3... are guardians
        require(_guardians[tokenId].length > 0, "ERC4973SoulContainer: approval quorum require at least one guardian");

        uint256 indexKey = _approverIndexKey(tokenId);
        _renewalApprovers[indexKey][_msgSenderERC4973()] = approved;
        
        emit ApproveRenew(tokenId, approved);
    }

    /**
     * @dev See {IERC4973SoulId-renew}.
     * Emits {Renew} event.
     * Emits {Transfer} event. (to support NFT platforms)
     */
    function renew(address to, uint256 tokenId) external virtual override {
        // access controls
        require(_isOwnerOrGuardian(_msgSenderERC4973(), tokenId), "ERC4973SoulContainer: renew with unauthorized access");
        require(_renewalRequest[tokenId].requester == _msgSenderERC4973(), "ERC4973SoulContainer: renew with invalid requester");

        // requirements
        require(!isRequestExpired(tokenId), "ERC4973SoulContainer: renew with expired request");
        require(isRequestApproved(tokenId), "ERC4973SoulContainer: renew with unapproved request");
        require(balanceOf(to) == 0, "ERC4973SoulContainer: renew to existing token address");
        require(to != address(0), "ERC4973SoulContainer: renew to zero address");

        address oldAddr = _ownerOf(tokenId);

        unchecked {
            _burn(tokenId);

            // update new address data
            _addressData[to].tokenId = tokenId;
            _addressData[to].balance = 1;
            _addressData[to].numberRenewal += 1;
            _addressData[to].createTimestamp = uint40(block.timestamp);
            _owners[tokenId] = to;

            // to avoid duplicated guardian address and the new token owner
            // remove guardian for the requester address
            if (_isGuardian(to, tokenId)){
                _removeGuardian(to, tokenId);
            }
        }

        emit Renew(to, tokenId);
        emit Transfer(oldAddr, to, tokenId);
    }

    /**
     * @dev Mints `tokenId` to `to` address.
     *
     * Requirements:
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     * - 1:1 mapping of token and address
     *
     * Emits {Attest} event.
     * Emits {Transfer} event. (to support NFT platforms)
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC4973SoulContainer: mint to the zero address");
        require(!_exists(tokenId), "ERC4973SoulContainer: token already minted");
        require(balanceOf(to) == 0, "ERC4973SoulContainer: one token per address");

        // Overflows are incredibly unrealistic.
        // max balance should be only 1
        unchecked {
            _addressData[to].tokenId = tokenId;
            _addressData[to].balance = 1;
            _addressData[to].numberMinted += 1;
            _addressData[to].createTimestamp = uint40(block.timestamp);
            _owners[tokenId] = to;
        }

        emit Attest(to, tokenId);
        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     *
     * Requirements:
     * - `tokenId` must exist.
     * 
     * Access:
     * - `tokenId` owner
     *
     * Emits {Revoke} event.
     * Emits {Transfer} event. (to support NFT platforms)
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = _ownerOf(tokenId);
        
        delete _addressData[owner].balance;
        _addressData[owner].numberBurned += 1;

        // delete will reset all struct variables to 0
        delete _owners[tokenId];
        delete _renewalRequest[tokenId];

        emit Revoke(owner, tokenId);
        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Burns `tokenId`. See {IERC4973-burn}.
     *
     * Access:
     * - `tokenId` owner
     */
    function burn(uint256 tokenId) public virtual override {
        require(ownerOf(tokenId) == _msgSenderERC4973(), "ERC4973SoulContainer: burn from non-owner");

        _burn(tokenId);
    }

    /**
     * @dev Returns the message sender (defaults to `msg.sender`).
     *
     * For GSN compatible contracts, you need to override this function.
     */
    function _msgSenderERC4973() internal view virtual returns (address) {
        return msg.sender;
    }

    // Converts `uint256` to ASCII `string`
    function _toString(uint256 value) internal pure returns (string memory ptr) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit),
            // but we allocate 128 bytes to keep the free memory pointer 32-byte word aliged.
            // We will need 1 32-byte word to store the length,
            // and 3 32-byte words to store a maximum of 78 digits. Total: 32 + 3 * 32 = 128.
            ptr := add(mload(0x40), 128)
            // Update the free memory pointer to allocate.
            mstore(0x40, ptr)

            // Cache the end of the memory to calculate the length later.
            let end := ptr

            // We write the string from the rightmost digit to the leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // Costs a bit more than early returning for the zero case,
            // but cheaper in terms of deployment and overall runtime costs.
            for {
                // Initialize and perform the first pass without check.
                let temp := value
                // Move the pointer 1 byte leftwards to point to an empty character slot.
                ptr := sub(ptr, 1)
                // Write the character to the pointer. 48 is the ASCII index of '0'.
                mstore8(ptr, add(48, mod(temp, 10)))
                temp := div(temp, 10)
            } temp {
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
            } {
                // Body of the for loop.
                ptr := sub(ptr, 1)
                mstore8(ptr, add(48, mod(temp, 10)))
            }

            let length := sub(end, ptr)
            // Move the pointer 32 bytes leftwards to make room for the length.
            ptr := sub(ptr, 32)
            // Store the length.
            mstore(ptr, length)
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[43] private __gap;
}
