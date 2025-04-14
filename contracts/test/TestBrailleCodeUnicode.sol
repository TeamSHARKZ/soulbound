// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * Test BrailleCodeUnicode
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

contract TestBrailleCodeUnicode {
    string public myname;

    function setName(string memory _name) external {
        myname = _name;
    }

    function readName(uint256 _i) external view returns (bytes1) {
        bytes memory buffer = bytes(myname);
        return buffer[_i];
    }

    function readNameUint8(uint256 _i) external view returns (uint8) {
        bytes memory buffer = bytes(myname);
        return uint8(buffer[_i]);
    }

    function toBrailleCodeUnicode(uint256 _value) 
        public 
        pure 
        returns (string memory) 
    {
        // base 256 codes Braille pattern unicode
        // @See https://www.htmlsymbols.xyz/braille-patterns
        uint256 base = 256;

        // Braille 0 = 0xe2a080
        if (_value == 0) {
            bytes memory zero = new bytes(3);
            zero[0] = 0xe2;
            zero[1] = 0xa0;
            zero[2] = 0x80;
            return string(zero);
        }
        // calculate string length
        uint256 temp = _value;
        uint256 digits = 0;
        while (temp != 0) {
            digits += 1;
            temp /= base;
        }
        // construct output string bytes
        // Solidity unicode character is 3 bytes long
        uint256 codeSize = 3;
        
        // Brallie Unicode, each byte is over 127 (avoid colliding Lower ASCII 32 - 127)
        // 1st bytes1 keeping at 0xe2 (uint8 226)
        // 2nd bytes1 starts at 0xa0 (uint8 160)
        // 3rd bytes1 starts at 0x80 (uint8 128)
        // Brallie unicode span 4 sections, each section contains only 64 numbers total 256 numbers.
        // Part 1: 0xe2a080 - 0xe2a0bf
        // Part 2: 0xe2a180 - 0xe2a1bf
        // Part 3: 0xe2a280 - 0xe2a2bf
        // Part 4: 0xe2a380 - 0xe2a3bf
        bytes memory buffer = new bytes(digits*codeSize);
        uint256 code;
        unchecked {
            while (_value != 0) {
                digits -= 1;
                // 1st byte always is the same
                buffer[digits*codeSize+0] = 0xe2;

                // 2nd byte number
                code = _value % base;
                if (code / 64 == 0) {
                    buffer[digits*codeSize+1] = 0xa0;
                } else if (code / 64 == 1) {
                    buffer[digits*codeSize+1] = 0xa1;
                } else if (code / 64 == 2) {
                    buffer[digits*codeSize+1] = 0xa2;
                } else if (code / 64 == 3) {
                    buffer[digits*codeSize+1] = 0xa3;
                }

                // 3rd byte, always starts at 128 to 191 (64 numbers)
                // after mod 64, it must fit in 1 bytes space of uint8
                buffer[digits*codeSize+2] = bytes1(uint8(128 + code % 64));

                _value /= base;
            }
        }
        return string(buffer);
    }

    /**
     * @dev See {ISoulData-isValidTokenCustomName}.
     */
    function isValidTokenCustomName(string calldata name) external pure returns (bool) {
        bytes memory data = bytes(name);
        uint8 char;
        for (uint256 i; i < data.length; i++) {
            char = uint8(data[i]);
            // accept A-Z:(64-90), a-z:(97-122), space(32)
            if ((char < 64 && char != 32) || (char > 90 && char < 97) || char > 122) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev See {ISoulData-toAlphabetCode}.
     */
    function toAlphabetCode(uint256 _value) 
        public 
        pure 
        returns (string memory) 
    {
        // base 26 alphabet codes starts from A
        if (_value == 0) {
            return "A";
        }
        // calculate string length
        uint256 temp = _value;
        uint256 letters = 0;
        while (temp != 0) {
            letters += 1;
            temp /= 26;
        }
        uint256 max = letters - 1;
        // construct output string bytes
        bytes memory buffer = new bytes(letters);
        while (_value != 0) {
            letters -= 1;
            if (letters < max) {
                buffer[letters] = bytes1(uint8(64 + uint256(_value % 26)));
            } else {
                buffer[letters] = bytes1(uint8(65 + uint256(_value % 26)));
            }
            _value /= 26;
        }
        return string(buffer);
    }

    /**
     * Converts `uint256` to ASCII `string`
     */
    function toString(uint256 value) 
        public 
        pure 
        returns (string memory ptr) 
    {
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