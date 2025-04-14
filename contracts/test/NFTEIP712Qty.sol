// SPDX-License-Identifier: Unlicense

/**                                                                  
 *******************************************************************************
 * EIP 712 whitelist with max mint qty
 * *****************************************************************************
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../lib/712/EIP712WhitelistQty.sol";

contract NFTEIP712Qty is ERC721, EIP712WhitelistQty {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("WhitelistToken", "TOKE") EIP712WhitelistQty() {}

    // Use the requiresWhitelist modifier to reject the call if a valid signature is not provided
    function whitelistMint(bytes calldata _signature, uint256 _qty)
        public
        checkWhitelist(_signature, _qty)
    {
        // Make sure to check other requirements before incrementing or minting
        _tokenIdCounter.increment();
        _safeMint(msg.sender, _tokenIdCounter.current());
    }

    function tokenURI() public pure returns (string memory) {
        return
            "ipfs://bafybeiaqofrinid75krvga6c2alksixzmhuddx3zxgwvmyhh7vsyjbv6tm";
    }

    function recoverSigner(bytes calldata _signature, uint256 _qty) public view returns (address) {
        return _recoverSigner(_signature, _qty);
    }
}