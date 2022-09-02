// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * ISoulIDData interface
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

/**
 * @dev Interface of Sharkz Soul ID Data storage and utilities
 */
interface ISoulData {
    /**
     * @dev Render tokenURI dynamic metadata string
     */
    function tokenURI(uint256 tokenId, string calldata metaName, string calldata metaDesc, string calldata badgeTraits, uint256 score, uint256 creationTime, string calldata customName) external view returns (string memory);

    /**
     * @dev Render token meta name, desc, and image
     */
    function tokenMetaAndImage(uint256 tokenId, string calldata metaName, string calldata metaDesc, uint256 creationTime, string calldata name) external view returns (string memory);

    /**
     * @dev Render token meta attributes
     */
    function tokenAttributes(string calldata badgeTraits, uint256 score, uint256 creationTime) external pure returns (string memory);

    /**
     * @dev Save/Update/Clear a page of data with a key, max size is 24576 bytes (24KB)
     */
    function saveData(string memory key, uint256 pageNumber, bytes memory data) external;

    /**
     * @dev Get all data from all data pages for a key
     */
    function getData(string memory key) external view returns (bytes memory);

    /**
     * @dev Get one page of data chunk
     */
    function getPageData(string memory key, uint256 pageNumber) external view returns (bytes memory);

    /**
     * @dev Returns external Token collection name
     */
    function getTokenCollectionName(address _contract) external view returns (string memory);

    /**
     * @dev Returns Soul Badge balance for a Soul
     */
    function getSoulBadgeBalanceForSoul(address soulContract, uint256 soulTokenId, address badgeContract) external view returns (uint256);

    /**
     * @dev Returns Badge base score (unit score per one qty
     */
    function getBadgeBaseScore(address badgeContract) external view returns (uint256);

    /**
     * @dev Returns the token metadata trait string for a badge contract (support ERC721 and ERC5114 Soul Badge)
     */
    function getBadgeTrait(address badgeContract, uint256 traitIndex, address soulContract, uint256 soulTokenId, address soulTokenOwner) external view returns (string memory);

    /**
     * @dev Returns whether an address is a ERC721 token owner
     */
    function getERC721Balance(address _contract, address ownerAddress) external view returns (uint256);

    /**
     * @dev Returns whether custom name contains valid characters
     *      We only accept [a-z], [A-Z], [space] and certain punctuations
     */
    function isValidCustomNameFormat(string calldata name) external pure returns (bool);

    /**
     * @dev Returns whether target contract reported it implementing an interface (based on IERC165)
     */
    function isImplementing(address _contract, bytes4 interfaceCode) external view returns (bool);
    
    /** 
     * @dev Converts a `uint256` to Unicode Braille patterns (0-255)
     * Braille patterns https://www.htmlsymbols.xyz/braille-patterns
     */
    function toBrailleCodeUnicode(uint256 value) external pure returns (string memory);

    /** 
     * @dev Converts a `uint256` to HTML code of Braille patterns (0-255)
     * Braille patterns https://www.htmlsymbols.xyz/braille-patterns
     */
    function toBrailleCodeHtml(uint256 value) external pure returns (string memory);

    /** 
     * @dev Converts a `uint256` to ASCII base26 alphabet sequence code
     * For example, 0:A, 1:B 2:C ... 25:Z, 26:AA, 27:AB...
     */
    function toAlphabetCode(uint256 value) external pure returns (string memory);

    /**
     * @dev Converts `uint256` to ASCII `string`
     */
    function toString(uint256 value) external pure returns (string memory ptr);
}