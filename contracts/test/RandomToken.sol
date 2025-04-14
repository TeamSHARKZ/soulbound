// SPDX-License-Identifier: MIT

/**                                                               
 *******************************************************************************
 * Random Token using temp storage variable
 * *****************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.0;

contract RandomToken {
    uint256 public constant MAX_SUPPLY = 101;
    
    // Random seed
    uint256 internal _randomSeed;
    
    // Minted token counter
    uint256 public totalMinted;

    mapping(uint256 => uint256) private _reservedTokens;

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
        uint256 seed = _randomSeed;
        uint256 max = MAX_SUPPLY;
        
        require(_qty > 0, "No mint quantity");
        require(seed != 0, "Random seed is missing");
        require(totalMinted + _qty <= max, "Max supply reached");
        
        for (uint256 i = 0; i < _qty; i++) {
            uint256 tokenId = _getRandomToken(seed, totalMinted, max);
            totalMinted++;

            // @@@@@@@@@@TESTONLY
            mintedTokens.push(tokenId);
        }
    }

    function _getRandomToken(uint256 _seed, uint256 _totalMinted, uint256 _maxSupply) internal returns (uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(_seed, _totalMinted)));
        uint256 remaining = _maxSupply - _totalMinted;

        // value of (1 ~ remaining)
        uint256 randomIndex = 1 + (random % remaining);

        // use the previously reserved token id instead of randomIndex value
        uint256 tokenId = _reservedTokens[randomIndex];
        if (tokenId == 0) {
            // random id is safe to use
            tokenId = randomIndex;
        }
        
        // no need to store any value if randomIndex is at max token id slot
        if (randomIndex != remaining) {
            uint256 lastToken = _reservedTokens[remaining];

            if (lastToken == 0) {
                // replace current token slot with current max token id
                _reservedTokens[randomIndex] = remaining;
            } else {
                // replace current token slot with last token slot value (previously saved)
                _reservedTokens[randomIndex] = lastToken;
                delete _reservedTokens[remaining];
            }
        }

        return tokenId;
    }
}