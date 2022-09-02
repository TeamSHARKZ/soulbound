// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.7;

/// @dev See https://eips.ethereum.org/EIPS/eip-5114
interface IERC5114 {
	// fired anytime a new instance of this token is minted
	// this event **MUST NOT** be fired twice for the same `tokenId`
	event Mint(uint256 indexed tokenId, address indexed nftAddress, uint256 indexed nftTokenId);

	// returns the NFT token that owns this token.
	// this function **MUST** throw if the token hasn't been minted yet
	// this function **MUST** always return the same result every time it is called after it has been minted
	// this function **MUST** return the same value as found in the original `Mint` event for the token
	function ownerOf(uint256 index) external view returns (address nftAddress, uint256 nftTokenId);
	
	// returns a censorship resistant URI with details about this token collection
	// the metadata returned by this is merged with the metadata return by `tokenUri(uint256)`
	// the collectionUri **MUST** be immutable and content addressable (e.g., ipfs://)
	// the collectionUri **MUST NOT** point at mutable/censorable content (e.g., https://)
	// data from `tokenUri` takes precedence over data returned by this method
	// any external links referenced by the content at `collectionUri` also **MUST** follow all of the above rules
	function collectionUri() external view returns (string calldata collectionUri);
	
	// returns a censorship resistant URI with details about this token instance
	// the tokenUri **MUST** be immutable and content addressable (e.g., ipfs://)
	// the tokenUri **MUST NOT** point at mutable/censorable content (e.g., https://)
	// data from this takes precedence over data returned by `collectionUri`
	// any external links referenced by the content at `tokenUri` also **MUST** follow all of the above rules
	function tokenUri(uint256 tokenId) external view returns (string calldata tokenUri);
}