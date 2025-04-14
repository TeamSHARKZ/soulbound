// SPDX-License-Identifier: Unlicense

/**                                                                  
 *******************************************************************************
 * EIP 712 whitelist
 * *****************************************************************************
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../lib/712/EIP712Whitelist.sol";

contract NFTEIP712 is ERC721, EIP712Whitelist {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("WhitelistToken", "TOKE") EIP712Whitelist() {}

    // Use the requiresWhitelist modifier to reject the call if a valid signature is not provided
    function whitelistMint(bytes calldata _signature)
        public
        checkWhitelist(_signature)
    {
        // Make sure to check other requirements before incrementing or minting
        _tokenIdCounter.increment();
        _safeMint(msg.sender, _tokenIdCounter.current());
    }

    function tokenURI() public pure returns (string memory) {
        return
            "ipfs://bafybeiaqofrinid75krvga6c2alksixzmhuddx3zxgwvmyhh7vsyjbv6tm";
    }

    function recoverSigner(bytes calldata _signature) public view returns (address) {
        return _recoverSigner(_signature);
    }
}