// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * IERC5114 Soul Badge interface
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "../lib/5114/IERC5114SoulBadge.sol";

contract InterfaceCode {
    function code() public pure returns(bytes4) {
        return type(IERC5114SoulBadge).interfaceId;
    }
}