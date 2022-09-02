// SPDX-License-Identifier: MIT

/**                                                                
 *******************************************************************************
 * Sharkz Soul ID Data
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./ISoulData.sol";
import "./IScore.sol";
import "./Adminable.sol";
import "../Base64.sol";

interface IBalanceOf {
  function balanceOf(address owner) external view returns (uint256 balance);
}

interface IBalanceOfSoul {
  function balanceOfSoul(address soulContract, uint256 soulTokenId) external view returns (uint256 balance);
}

interface IName {
  function name() external view returns (string memory);
}

contract SoulData is ISoulData, Adminable {
    struct ContractData {
        address rawContract;
        uint16 size;
    }

    struct ContractDataPages {
        uint256 maxPageNumber;
        bool exists;
        mapping (uint256 => ContractData) pages;
    }

    // Mapping from string key to on-chain contract data storage 
    mapping (string => ContractDataPages) internal _contractDataPages;

    // Token image key
    string public tokenImageKey;

    // TokenURI Render mode
    // 0 : data:application/json;utf8, token image data:image/svg+xml;base64
    // 1 : data:application/json;utf8, token image data:image/svg+xml;utf8
    // 2 : data:application/json;base64, token image data:image/svg+xml;base64
    // 3 : data:application/json;base64, token image data:image/svg+xml;utf8
    uint256 internal _tokenURIMode;

    // Trait type index sequence coding mode
    // 0 : Braille unicode
    // 1 : Alphabet code, A, B, C, ..., Z, AA, AB ...
    uint256 internal _traitTypeSeqCoding;

    constructor() {
        tokenImageKey = "svgHead";
    }

    //////// Admin-only functions ////////
    /**
     * @dev See {ISoulData-saveData}.
     */
    function saveData(
        string memory _key, 
        uint256 _pageNumber, 
        bytes memory _b
    )
        external 
        onlyAdmin 
    {
        require(_b.length <= 24576, "Exceeded 24,576 bytes max contract space");
        /**
         * 
         * `init` variable is the header of contract data
         * 61_00_00 -- PUSH2 (contract code size)
         * 60_00 -- PUSH1 (code position)
         * 60_00 -- PUSH1 (mem position)
         * 39 CODECOPY
         * 61_00_00 PUSH2 (contract code size)
         * 60_00 PUSH1 (mem position)
         * f3 RETURN
         *
        **/
        bytes memory init = hex"610000_600e_6000_39_610000_6000_f3";
        bytes1 size1 = bytes1(uint8(_b.length));
        bytes1 size2 = bytes1(uint8(_b.length >> 8));
        // 2 bytes = 2 x uint8 = 65,536 max contract code size
        init[1] = size2;
        init[2] = size1;
        init[9] = size2;
        init[10] = size1;
        
        // contract code content
        bytes memory code = abi.encodePacked(init, _b);

        // create the contract
        address dataContract;
        assembly {
            dataContract := create(0, add(code, 32), mload(code))
            if eq(dataContract, 0) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        // record the created contract data page
        _saveDataRecord(
            _key,
            _pageNumber,
            dataContract,
            _b.length
        );
    }

    // store the generated contract data store address
    function _saveDataRecord(
        string memory _key,
        uint256 _pageNumber,
        address _dataContract,
        uint256 _size
    )
        internal
    {
        // Pull the current data for the contractData
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // Store the maximum page
        if (_cdPages.maxPageNumber < _pageNumber) {
            _cdPages.maxPageNumber = _pageNumber;
        }

        // Keep track of the existance of this key
        _cdPages.exists = true;

        // Add the page to the location needed
        _cdPages.pages[_pageNumber] = ContractData(
            _dataContract,
            uint16(_size)
        );
    }
    
    // Change token image key
    function setTokenImageKey(string calldata _tokenImageKey) external onlyAdmin {
        tokenImageKey = _tokenImageKey;
    }

    // Update tokenURI render mode
    function setTokenURIMode(uint256 _mode) external onlyAdmin {
        _tokenURIMode = _mode;
    }

    // Update trait type index sequence coding mode
    function setTraitSeqCoding(uint256 _mode) external onlyAdmin {
        _traitTypeSeqCoding = _mode;
    }

    //////// End of Admin-only functions ////////

    /**
     * @dev See {ISoulData-getPageData}.
     */
    function getPageData(
        string memory _key,
        uint256 _pageNumber
    )
        external 
        view 
        returns (bytes memory)
    {
        ContractDataPages storage _cdPages = _contractDataPages[_key];
        
        require(_pageNumber <= _cdPages.maxPageNumber, "Page number not in range");
        bytes memory _totalData = new bytes(_cdPages.pages[_pageNumber].size);

        // For each page, pull and compile
        uint256 currentPointer = 32;

        ContractData storage dataPage = _cdPages.pages[_pageNumber];
        address dataContract = dataPage.rawContract;
        uint256 size = uint256(dataPage.size);
        uint256 offset = 0;

        // Copy directly to total data
        assembly {
            extcodecopy(dataContract, add(_totalData, currentPointer), offset, size)
        }
        return _totalData;
    }

    /**
     * @dev See {ISoulData-getData}.
     */
    function getData(
        string memory _key
    )
        public 
        view 
        returns (bytes memory)
    {
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // Determine the total size
        uint256 totalSize;
        for (uint256 idx; idx <= _cdPages.maxPageNumber; idx++) {
            totalSize += _cdPages.pages[idx].size;
        }

        // Create a region large enough for all of the data
        bytes memory _totalData = new bytes(totalSize);

        // For each page, pull and compile
        uint256 currentPointer = 32;
        for (uint256 idx; idx <= _cdPages.maxPageNumber; idx++) {
            ContractData storage dataPage = _cdPages.pages[idx];
            address dataContract = dataPage.rawContract;
            uint256 size = uint256(dataPage.size);
            uint256 offset = 0;

            // Copy directly to total data
            assembly {
                extcodecopy(dataContract, add(_totalData, currentPointer), offset, size)
            }

            // Update the current pointer
            currentPointer += size;
        }

        return _totalData;
    }

    /**
     * @dev See {ISoulData-tokenURI}.
     */
    function tokenURI(uint256 _tokenId, string calldata _metaName, 
                      string calldata _metaDesc, string calldata _badgeTraits, uint256 _score, 
                      uint256 _creationTime, string calldata _customName) 
        external 
        view  
        returns (string memory) 
    {
        bytes memory output = abi.encodePacked(
            tokenMetaAndImage(_tokenId, _metaName, _metaDesc, _creationTime, _customName),
            tokenAttributes(_badgeTraits, _score, _creationTime)
        );

        // TokenURI Render mode
        // 0 : data:application/json;utf8, token image data:image/svg+xml;base64
        // 1 : data:application/json;utf8, token image data:image/svg+xml;utf8
        // 2 : data:application/json;base64, token image data:image/svg+xml;base64
        // 3 : data:application/json;base64, token image data:image/svg+xml;utf8
        if (_tokenURIMode == 0 || _tokenURIMode == 1) {
            return string(abi.encodePacked("data:application/json;utf8,", output));
        } else {
            return string(abi.encodePacked("data:application/json;base64,", Base64.encode(output)));
        }
    }

    /**
     * @dev See {ISoulData-tokenMetaAndImage}.
     */
    function tokenMetaAndImage(uint256 _tokenId, string calldata _metaName, string calldata _metaDesc, uint256 _creationTime, string calldata _name) 
        public  
        view 
        returns (string memory) 
    {
        string memory tokenImage = string(abi.encodePacked(
            string(getData(tokenImageKey)),
            _svgText(
              _name,
              "8.5",
              "208", 
              "107.8", 
              "4"
            ),
            _svgText(
              string(abi.encodePacked(toString(_creationTime),"#",toString(_tokenId))),
              "11",
              "208", 
              "251.5", 
              "4"
            ),
            "</svg>"
        ));

        // 0 : data:application/json;utf8, token image data:image/svg+xml;base64
        // 1 : data:application/json;utf8, token image data:image/svg+xml;utf8
        // 2 : data:application/json;base64, token image data:image/svg+xml;base64
        // 3 : data:application/json;base64, token image data:image/svg+xml;utf8
        if (_tokenURIMode == 0 || _tokenURIMode == 2) {
            return string(abi.encodePacked(
                '{"name":"', _metaName, toString(_tokenId), '","description":"', _metaDesc, '","image":"data:image/svg+xml;base64,', Base64.encode(bytes(tokenImage)), '",'
            ));
        } else {
            return string(abi.encodePacked(
                '{"name":"', _metaName, toString(_tokenId), '","description":"', _metaDesc, '","image":"data:image/svg+xml;utf8,', tokenImage, '",'
            ));
        }
        
        
    }

    /**
     * @dev See {ISoulData-tokenAttributes}.
     */
    function tokenAttributes(string calldata _badgeTraits, uint256 _score, uint256 _creationTime) 
        public  
        pure 
        returns (string memory) 
    {
        return string(abi.encodePacked('"attributes":[',
            '{"trait_type":"Creation Time","value":', toString(_creationTime), ',"display_type": "date"},',
            _badgeTraits,
            '{"trait_type":"Score","value":', toString(_score), '}]}'
        ));
    }

    // render dynamic svg <text> element with token internal data
    function _svgText(string memory _text, string memory _fontSize, string memory _x, string memory _y, string memory _rotate) 
        internal 
        pure 
        returns (string memory) 
    {
        if (bytes(_text).length > 0) {
            // sample output: 
            // <text text-anchor='middle' x='208' y='241.5' fill='#8ecad8' font-family='custom' 
            //  font-size='8.5' transform='rotate(4)' letter-spacing='0.5'>1626561212#471</text>
            return string(abi.encodePacked(
                "<text text-anchor='middle' x='", _x, "' y='", _y ,"' fill='#8ecad8' font-family='custom' font-size='",_fontSize,
                "' transform='rotate(", _rotate, ")' letter-spacing='0.5'>", _svgSpace(_text),"</text>"
            ));
        }

        return "";
    }

    // convert space charachter to better svg text space
    function _svgSpace(string memory _name) 
        internal  
        pure 
        returns (string memory)
    {
        bytes memory input = bytes(_name);
        bytes memory output;
        uint256 index;
        while(index < input.length) {
            // replace "space" to "&#160;"
            if (keccak256(abi.encodePacked(input[index])) == keccak256(abi.encodePacked(" "))) {
                output = abi.encodePacked(output, "&#160;&#160;");
            } else {
                output = abi.encodePacked(output, input[index]);
            }
            index += 1;
        }
        return string(output);
    }

    /**
     * @dev See {ISoulData-getTokenCollectionName}.
     */
    function getTokenCollectionName(address _contract) public view returns (string memory) {
        try IName(_contract).name() returns (string memory name) {
            return name;
        } catch (bytes memory) {
            // when reverted, just returns...
            return "";
        }
    }

    /**
     * @dev See {ISoulData-getBadgeBaseScore}.
     */
    function getBadgeBaseScore(address _badgeContract) external view returns (uint256) {
        try IScore(_badgeContract).baseScore() returns (uint256 score) {
            return score;
        } catch (bytes memory) {
            // when reverted, just returns...
            return 0;
        }
    }

    /**
     * @dev See {ISoulData-getBadgeTrait}.
     */
     function getBadgeTrait(address _badgeContract, uint256 _traitIndex, address _soulContract, uint256 _soulTokenId, address _soulTokenOwner) 
        external 
        view 
        returns (string memory) 
    {
        string memory output;
        string memory traitName;
        string memory traitValue;

        traitValue = getTokenCollectionName(_badgeContract);
        uint256 traitValueLength = bytes(traitValue).length;

        // generate sequence code for multiple dynamic trait index number
        string memory traitSeqCode;
        if (_traitTypeSeqCoding == 0) {
            traitSeqCode = toBrailleCodeUnicode(_traitIndex);
        } else {
            traitSeqCode = toAlphabetCode(_traitIndex);
        }

        // ERC165 interface ID for ERC721 is 0x80ac58cd
        if (isImplementing(_badgeContract, 0x80ac58cd)) {
            // target contract is ERC721
            if (getERC721Balance(_badgeContract, _soulTokenOwner) > 0) {
                if (traitValueLength != 0) {
                    traitName = string(abi.encodePacked("ERC721 NFT ", traitSeqCode));
                    output = string(abi.encodePacked(output, '{"trait_type":"',traitName,'","value":"',traitValue, '"},'));
                }
            }
        } else {
            // target contract is Soul Badge contracts
            if (getSoulBadgeBalanceForSoul(_soulContract, _soulTokenId, _badgeContract) > 0) {
                if (traitValueLength != 0) {
                    traitName = string(abi.encodePacked("Soul Badge ", traitSeqCode));
                    output = string(abi.encodePacked(output, '{"trait_type":"',traitName,'","value":"',traitValue, '"},'));
                }
            }    
        }
        return output;
    }

    /**
     * @dev See {ISoulData-getSoulBadgeBalanceForSoul}.
     */
    function getSoulBadgeBalanceForSoul(address _soulContract, uint256 _soulTokenId, address _badgeContract) public view returns (uint256) {
        if (_soulContract == address(0) || _badgeContract == address(0)) return 0;
        
        try IBalanceOfSoul(_badgeContract).balanceOfSoul(_soulContract, _soulTokenId) returns (uint256 rtbal) {
            return rtbal;
        } catch (bytes memory) {
            // when reverted, just returns...
            return 0;
        }
    }

    /**
     * @dev See {ISoulData-getERC721Balance}.
     */
    function getERC721Balance(address _contract, address _ownerAddress) public view returns (uint256) {
        if (_contract == address(0) || _ownerAddress == address(0)) return 0;

        try IBalanceOf(_contract).balanceOf(_ownerAddress) returns (uint256 balance) {
            return balance;
        } catch (bytes memory) {
            // when reverted, just returns...
            return 0;
        }
    }

    /**
     * @dev See {ISoulData-isValidCustomNameFormat}.
     */
    function isValidCustomNameFormat(string calldata name) external pure returns (bool) {
        bytes memory data = bytes(name);
        uint8 char;
        for (uint256 i; i < data.length; i++) {
            char = uint8(data[i]);
            // accepted char: space(32) ,(44) -(45) .(46) :(58) A-Z:(64-90) a-z:(97-122)
            if (!(char == 32 || (char >= 44 && char <= 46) || (char == 58) 
                  || (char >= 64 && char <= 90) || (char >= 97 && char <= 122) )) {
              return false;
            }
        }
        return true;
    }

    /**
     * @dev See {ISoulData-isImplementing}.
     */
    function isImplementing(address _contract, bytes4 _interfaceCode) public view returns (bool) {
        try IERC165(_contract).supportsInterface(_interfaceCode) returns (bool result) {
            return result;
        } catch (bytes memory) {
            // when reverted, just returns...
            return false;
        }
    }

    /**
     * @dev See {ISoulData-toBrailleCodeUnicode}.
     */
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
                // 1st byte always the same
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
                // after mod 64, convert to uint8, it will fit in 1 byte
                buffer[digits*codeSize+2] = bytes1(uint8(128 + code % 64));

                _value /= base;
            }
        }
        return string(buffer);
    }

    /**
     * @dev See {ISoulData-toBrailleCodeHtml}.
     */
    function toBrailleCodeHtml(uint256 _value) 
        public 
        pure 
        returns (string memory) 
    {
        // base 256 codes html code from [&#10240;] to [&#10495;]
        // https://www.htmlsymbols.xyz/braille-patterns
        uint256 base = 256;

        if (_value == 0) {
            return "&#10240;";
        }
        // calculate string length
        uint256 temp = _value;
        uint256 digits = 0;
        while (temp != 0) {
            digits += 1;
            temp /= base;
        }
        // construct output string bytes
        bytes memory buffer = new bytes(digits*8);
        uint256 code;
        bytes memory codeChars;
        uint256 codeCharIndex;
        unchecked {
            while (_value != 0) {
                digits -= 1;
                // calculate brallie html code number, from 10240 - 10495 (base 256)
                // and format as  &#{code};  string bytes
                code = 10240 + _value % base;
                codeChars = bytes(toString(code));
                buffer[digits*8+0] = bytes1("&");
                buffer[digits*8+1] = bytes1("#");
                for (codeCharIndex = 0; codeCharIndex < codeChars.length; codeCharIndex ++) {
                    buffer[digits*8+2+codeCharIndex] = codeChars[codeCharIndex];
                }
                buffer[digits*8+7] = bytes1(";");
                _value /= base;
            }
        }
        return string(buffer);
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