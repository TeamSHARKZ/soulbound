// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * ERC5114 Soul Badge
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "./IERC5114SoulBadge.sol";

interface IOwnerOf {
  function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract ERC5114SoulBadge is IERC5114SoulBadge {
    // Structure to store each Soul token's badges data
    // Compiler will pack this into a single 256bit word.
    struct SoulTokenData {
        // 2**64-1 is more than enough
        // Keep track of final token balance
        uint64 balance;
        // Keep track of minted amount
        uint96 numberMinted;
        // Keeps track of burn count
        uint96 numberBurned;
    }

    // Mapping from `Soul contract, Soul tokenId` to token info
    mapping (address => mapping (uint256 => SoulTokenData)) internal _soulData;

    // Mapping from `badge tokenId` to `Soul contract`
    mapping (uint256 => address) public soulContracts;

    // Mapping from `badge tokenId` to `Soul tokenId`
    mapping (uint256 => uint256) public soulTokens;

    // How many badges can be attached to a `Soul`, zero means unlimited
    uint256 public maxTokenPerSoul;

    // How many badges can be minted from a `Soul`, zero means unlimited
    uint256 public maxMintPerSoul;

    // Token name {IERC5114SoulBadge-name}
    string public name;

    // Token symbol {IERC5114SoulBadge-symbol}
    string public symbol;

    // Immuntable collection uri
    string public collectionInfo;

    // Immuntable token base uri
    string public tokenBaseUri;

    constructor(string memory name_, string memory symbol_, string memory collectionUri_, string memory tokenBaseUri_) {
        name = name_;
        symbol = symbol_;
        collectionInfo = collectionUri_;
        tokenBaseUri = tokenBaseUri_;
        maxTokenPerSoul = 1;
        maxMintPerSoul = 0;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 interface ID for ERC165.
            interfaceId == 0x5b5e139f || // ERC165 interface ID for ERC721Metadata.
            interfaceId == type(IERC5114).interfaceId ||
            interfaceId == type(IERC5114SoulBadge).interfaceId;
    }

    // Returns whether `tokenId` exists.
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return soulContracts[tokenId] != address(0);
    }

    // Returns Soul address and Soul token id
    function _getSoul(uint256 tokenId) internal view virtual returns (address, uint256) {
        address soulContract = soulContracts[tokenId];
        uint256 soulTokenId = soulTokens[tokenId];
        require(soulContract != address(0), "ERC5114SoulBadge: Soul token owner not found");
        return (soulContract, soulTokenId);
    }

    // Returns the current owner address of a `Soul`
    function _getSoulOwnerAddress(address soulContract, uint256 soulTokenId) internal view virtual returns (address) {
        try IOwnerOf(soulContract).ownerOf(soulTokenId) returns (address ownerAddress) {
            if (ownerAddress != address(0)) {
                return ownerAddress;
            } else {
                revert("ERC5114SoulBadge: Soul token owner not found");
            }
        } catch (bytes memory) {
            revert("ERC5114SoulBadge: Soul token owner not found");
        }
    }

    /**
     * @dev See {IERC5114SoulBadge-balanceOfSoul}.
     */
    function balanceOfSoul(address soulContract, uint256 soulTokenId) external view virtual override returns (uint256) {
        require(soulContract != address(0), "ERC5114SoulBadge: balance query for the zero address");
        return _soulData[soulContract][soulTokenId].balance;
    }

    /**
     * @dev See {IERC5114SoulBadge-soulOwnerOf}.
     */
    function soulOwnerOf(uint256 tokenId) public view virtual override returns (address) {
        (address soulContract, uint256 soulTokenId) = _getSoul(tokenId);
        return _getSoulOwnerAddress(soulContract, soulTokenId);
    }
    
    /**
     * @dev See {IERC5114-ownerOf}.
     */
    function ownerOf(uint256 tokenId) external view virtual override returns (address, uint256) {
        return _getSoul(tokenId);
    }

    // Returns the number of tokens minted by `Soul`
    function _numberMinted(address soulContract, uint256 soulTokenId) internal view returns (uint256) {
        return uint256(_soulData[soulContract][soulTokenId].numberMinted);
    }

    // Returns the number of tokens burned by `Soul`
    function _numberBurned(address soulContract, uint256 soulTokenId) internal view returns (uint256) {
        return uint256(_soulData[soulContract][soulTokenId].numberBurned);
    }

    /**
     * @dev Mints `tokenId` to a Soul (Soul contract, Soul token id)
     *
     * Requirements:
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     * - max token per `Soul` not reached
     * - max minting count per `Soul` not reached
     *
     * Emits {Mint} event.
     */
    function _mint(uint256 tokenId, address soulContract, uint256 soulTokenId) internal virtual {
        require(soulContract != address(0), "ERC5114SoulBadge: mint to the zero address");
        require(!_exists(tokenId), "ERC5114SoulBadge: token already minted");
        require(maxTokenPerSoul == 0 || _soulData[soulContract][soulTokenId].balance < maxTokenPerSoul, "ERC5114SoulBadge: max token per soul reached");
        require(maxMintPerSoul == 0 || _soulData[soulContract][soulTokenId].numberMinted < maxMintPerSoul, "ERC5114SoulBadge: max minting per soul reached");

        // Overflows are incredibly unrealistic.
        unchecked {
            soulContracts[tokenId] = soulContract;
            soulTokens[tokenId] = soulTokenId;
            _soulData[soulContract][soulTokenId].balance += 1;
            _soulData[soulContract][soulTokenId].numberMinted += 1;
        }

        emit Mint(tokenId, soulContract, soulTokenId);
    }

    /**
     * @dev See {IERC5114-collectionUri}.
     */
    function collectionUri() external view virtual override returns (string memory) {
        return collectionInfo;
    }

    /**
     * @dev See {IERC5114-tokenUri}. Alias to tokenURI()
     */
    function tokenUri(uint256 tokenId) external view virtual override returns (string memory) {
        return tokenURI(tokenId);
    }

    // Return tokenURI meta data for each `tokenId`
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC5114SoulBadge: URI query for non-existent token");
        return string(abi.encodePacked(tokenBaseUri, _toString(tokenId), ".json"));
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
     * Emits {Burn} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address soulContract = soulContracts[tokenId];
        uint256 soulTokenId = soulTokens[tokenId];
        delete soulContracts[tokenId];
        delete soulTokens[tokenId];
        
        _soulData[soulContract][soulTokenId].balance -= 1;
        _soulData[soulContract][soulTokenId].numberBurned += 1;

        emit Burn(tokenId, soulContract, soulTokenId);
    }

    /**
     * @dev Burns `tokenId`. See {IERC5114-burn}.
     *
     * Access:
     * - `tokenId` owner
     */
    function burn(uint256 tokenId) public virtual override {
        require(soulOwnerOf(tokenId) == _msgSenderERC5114(), "ERC5114SoulBadge: burn from non-owner"); 
        _burn(tokenId);
    }

    /**
     * @dev Returns the message sender (defaults to `msg.sender`).
     *
     * For GSN compatible contracts, you need to override this function.
     */
    function _msgSenderERC5114() internal view virtual returns (address) {
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
}