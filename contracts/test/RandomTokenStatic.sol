// SPDX-License-Identifier: MIT

/**                                                               
 *******************************************************************************
 * Random Token static shuffle method
 * *****************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.0;

contract RandomTokenStatic {
    uint256 public constant MAX_SUPPLY = 101;

    // Random seed
    uint256 internal _randomSeed;
    
    // Minted token counter
    uint256 public totalMinted;

    // @@@@@@@@@@TESTONLY
    uint256[] public mintedTokens;

    constructor() {
       _randomSeed = uint256(blockhash(block.number - 1));
    }

    // @@@@@@@@@@TESTONLY
    function getMintedTokens() external view returns (uint[] memory) {
        return mintedTokens;
    }

    function mint(uint256 _qty) external {
        // uint256 seed = _randomSeed;
        uint256 max = MAX_SUPPLY;
        
        require(_qty > 0, "No mint quantity");
        require(_randomSeed != 0, "Random seed is missing");
        require(totalMinted + _qty <= max, "Max supply reached");
        
        for (uint256 i = 0; i < _qty; i++) {
            // token index is 1 ~ n
            uint256 tokenId = getRandomTokenByIndex(++totalMinted);

            // @@@@@@@@@@TESTONLY
            mintedTokens.push(tokenId);
        }
    }

    // generate a random ids array for the given pool size
    function _getRandomIds(uint256 seed, uint256 size) internal pure returns (uint256[] memory) {
        require(seed > 0, "Random seed is zero");

        uint[] memory ids = new uint[](size + 1);
        for (uint i = 1; i <= size; i += 1) {
            ids[i] = i;
        }
        for (uint i = 1; i <= size; i += 1) {
            uint swap = 1 + (uint(keccak256(abi.encode(seed,i))) % size);
            (ids[i], ids[swap]) = (ids[swap], ids[i]);
        }
        return ids;
    }

    // get the randomized token id at index position, index should start from 1 ~ n
    function getRandomTokenByIndex(uint256 _index) public view returns (uint256) {
        uint256[] memory ids = _getRandomIds(_randomSeed, MAX_SUPPLY);
        return ids[_index];
    }
}