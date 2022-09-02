// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTERC721 is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("NFTERC721", "NFTERC721") {}

    function ownerMint(address _to, uint256 _qty) public {
        _runMint(_to, _qty);
    }

    function _runMint(address _to, uint256 _qty) private {
        require(_qty > 0, "No mint quantity");

        for (uint256 i = 0; i < _qty; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _mint(_to, tokenId);
        }
    }
}