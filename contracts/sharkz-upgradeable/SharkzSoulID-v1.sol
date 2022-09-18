// SPDX-License-Identifier: MIT

/**
       █                                                                        
▐█████▄█ ▀████ █████  ▐████    ████████    ███████████  ████▌  ▄████ ███████████
▐██████ █▄ ▀██ █████  ▐████   ██████████   ████   ████▌ ████▌ ████▀       ████▀ 
  ▀████ ███▄ ▀ █████▄▄▐████  ████ ▐██████  ████▄▄▄████  █████████        ████▀  
▐▄  ▀██ █████▄ █████▀▀▐████ ▄████   ██████ █████████    █████████      ▄████    
▐██▄  █ ██████ █████  ▐█████████▀    ▐█████████ ▀████▄  █████ ▀███▄   █████     
▐████  █▀█████ █████  ▐████████▀        ███████   █████ █████   ████ ███████████
       █
 *******************************************************************************
 * Sharkz Soul ID
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../lib/sharkz/ISoulData.sol";
import "../lib/sharkz/IScore.sol";
import "../lib-upgradeable/sharkz/AdminableUpgradeable.sol";
import "../lib-upgradeable/712/EIP712WhitelistUpgradeable.sol";
import "../lib-upgradeable/4973/ERC4973SoulContainerUpgradeable.sol";

contract SharkzSoulIDV1 is IScore, Initializable, UUPSUpgradeable, AdminableUpgradeable, EIP712WhitelistUpgradeable, ERC4973SoulContainerUpgradeable, ReentrancyGuardUpgradeable {
    // Implementation version number
    function version() external pure virtual returns (string memory) { return "1.1"; }
    
    // Emits when new Badge contract is registered
    event BadgeContractLinked(address indexed addr);

    // Emits when existing Badge contract removed
    event BadgeContractUnlinked(address indexed addr);

    // Keep track of total minted token count
    uint256 internal _tokenMinted;

    // Keep track of total destroyed token
    uint256 internal _tokenBurned;

    // Public mint mode, 0: disable-minting, 1: free-mint, 2: restrict minting to target token owner
    uint256 internal _mintMode;

    // Max mint supply
    uint256 internal _mintSupply;

    // Restricted public mint with target token contract
    address internal _tokenContract;

    // Minting by claim contract
    address internal _claimContract;

    // Token metadata, name prefix
    string internal _metaName;

    // Token metadata, description
    string internal _metaDesc;

    // Compiler will pack the struct into multiple uint256 space
    struct BadgeSetting {
        address contractAddress;
        // limited to 2**80-1 score value 
        uint80 baseScore;
        // limited to 2**16 = 255x multiplier
        uint16 scoreMultiplier;
    }

    // Badge contract settings
    BadgeSetting[] public badgeSettings;

    // Link to Soul Data contract
    ISoulData public soulData;

    // Base score
    uint256 internal _baseScore;

    // Name on token image svg
    mapping (uint256 => string) public tokenCustomNames;

    // Init this upgradeable contract
    function initialize() public initializer onlyProxy {
        __Adminable_init();
        __EIP712Whitelist_init();
        __ERC4973SoulContainer_init("SOULID", "SOULID");
        __ReentrancyGuard_init();
        _metaName = "Soul ID #";
        _metaDesc = "Soul ID is a 100% on-chain generated token based on ERC4973-Soul Container designed by Sharkz Entertainment. Owning the Soul ID is your way to join our decentralized governance, participate and gather rewards in our NFT community ecosystem.";
        // default mint supply 100k
        _mintSupply = 100000;
        // default score is 1
        _baseScore = 1;
    }

    // only admins can upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        // See: https://eips.ethereum.org/EIPS/eip-165
        // return true to show proof of supporting following interface, we use bytes4 
        // interface id to avoid importing the whole interface codes.
        return super.supportsInterface(interfaceId) || 
               interfaceId == type(IScore).interfaceId;
    }

    // Returns whether badge contract is linked
    function isBadgeContractLinked(address addr) public view virtual returns (bool) {
        for (uint256 i = 0; i < badgeSettings.length; i++) {
          if (addr == badgeSettings[i].contractAddress)
          {
            return true;
          }
        }
        return false;
    }

    // Returns badge setting index by badge contract address
    function _badgeSettingIndex(address addr) internal view virtual returns (uint256) {
        for (uint256 i = 0; i < badgeSettings.length; i++) {
            if (addr == badgeSettings[i].contractAddress && addr != address(0)) {
                return i;
            }
        }
        revert("Badge contract index not found");
    }

    // Register a badge contract
    function _linkBadgeContract(address _contract, uint256 _scoreMultiplier) internal virtual {
        BadgeSetting memory object;
        object.contractAddress = _contract;
        object.scoreMultiplier = uint16(_scoreMultiplier);

        if (soulData.isImplementing(_contract, type(IScore).interfaceId)) {
            // copy the base score to avoid future access to external contract
            object.baseScore = uint80(soulData.getBadgeBaseScore(_contract));
        } else {
            // default set to 1 to allow badge count for NFT balance
            object.baseScore = 1;
        }

        badgeSettings.push(object);
        emit BadgeContractLinked(_contract);
    }

    // Remove registration of a badge contract
    function _unlinkBadgeContract(address _contract) internal virtual {
        uint256 total = badgeSettings.length;

        // replace current array element with last element, and pop() remove last element
        if (_contract != badgeSettings[total - 1].contractAddress) {
            uint256 index = _badgeSettingIndex(_contract);
            badgeSettings[index] = badgeSettings[total - 1];
            badgeSettings.pop();
        } else {
            badgeSettings.pop();
        }

        emit BadgeContractUnlinked(_contract);
    }

    // Returns the token voting score
    function _tokenVotingScore(uint256 _tokenId) internal virtual view returns (uint256) {
        // initial score for current token
        uint256 totalScore = baseScore();

        // loop through each badge contract to accumulate all score (with multiplier)
        BadgeSetting memory badge;
        for (uint256 i = 0; i < badgeSettings.length; i++) {
            badge = badgeSettings[i];

            if (soulData.isImplementing(badge.contractAddress, 0x80ac58cd)) {
                // for ERC721
                totalScore += badge.scoreMultiplier * badge.baseScore * soulData.getERC721Balance(badge.contractAddress, _ownerOf(_tokenId));
            } else {
                // for Soul Badge
                totalScore += badge.scoreMultiplier * badge.baseScore * soulData.getSoulBadgeBalanceForSoul(address(this), _tokenId, badge.contractAddress);
            }
        }

        return totalScore;
    }

    // Returns total linked badge contract counter
    function totalBadges() public view virtual returns (uint256) {
        return badgeSettings.length;
    }

    /**
     * @dev See {IScore-baseScore}.
     */
    function baseScore() public view virtual override returns (uint256) {
        return _baseScore;
    }

    /**
     * @dev See {IScore-scoreByToken}.
     */
    function scoreByToken(uint256 _tokenId) external view virtual override returns (uint256) {
        if (_exists(_tokenId)) {
          return _tokenVotingScore(_tokenId);
        } else {
          return 0;
        }
    }

    /**
     * @dev See {IScore-scoreByAddress}.
     */
    function scoreByAddress(address _addr) external view virtual override returns (uint256) {
        if (_addressData[_addr].balance > 0) {
            return _tokenVotingScore(tokenIdOf(_addr));
        } else {
            return 0;
        }
    }

    //////// Admin-only functions ////////

    // Link/unlink Badge contract
    // Noted that score multiplier is limited to the max value from BadgeSetting struct
    function setBadgeContract(address _contract, uint256 _scoreMultiplier, bool approved) 
        external 
        virtual 
        onlyAdmin 
    {
        bool exists = isBadgeContractLinked(_contract);
        
        // approve = true, adding
        // approve = false, removing
        if (approved) {
            require(!exists, "Adding existing badge contract");

            // target contract should at least implement ERC721Metadata to provide token name()
            require(soulData.isImplementing(_contract, 0x5b5e139f), "Target contract need to support ERC721Metadata");
            _linkBadgeContract(_contract, _scoreMultiplier);
        } else {
            require(exists, "Removing non-existent badge contract");
            _unlinkBadgeContract(_contract);
        }
    }

    // Setup contract data storage
    function setSoulDataContract(address _contract) 
        external 
        virtual 
        onlyAdmin 
    {
        soulData = ISoulData(_contract);
    }

    // Update token meta data desc
    function setTokenDescription(string calldata _desc) external virtual onlyAdmin {
        _metaDesc = _desc;
    }

    // Change minting mode
    function setMintMode(uint256 _mode) external virtual onlyAdmin {
        _mintMode = _mode;
    }

    // Change mint supply
    function setMintSupply(uint256 _max) external virtual onlyAdmin {
        _mintSupply = _max;
    }

    // Update linking ERC721 contract address
    function setMintRestrictContract(address _addr) external virtual onlyAdmin {
        _tokenContract = _addr;
    }

    // Update linking claim contract
    function setClaimContract(address _addr) external virtual onlyAdmin {
        _claimContract = _addr;
    }
    
    // Change base score
    function setBaseScore(uint256 _score) external virtual onlyAdmin {
        _baseScore = _score;
    }

    // Minting by admin to any address
    function ownerMint(address _to) 
        external 
        virtual 
        onlyAdmin 
    {
        _runMint(_to);
    }

    //////// End of Admin-only functions ////////

    // Returns total valid token count
    function totalSupply() public virtual view returns (uint256) {
        return _tokenMinted - _tokenBurned;
    }

    // Caller must not be an wallet account
    modifier callerIsUser() {
        require(tx.origin == _msgSenderERC4973(), "Caller should not be a contract");
        _;
    }

    // Create a new token for an address
    function _runMint(address _to) 
        internal 
        virtual 
        nonReentrant 
        onlyProxy
    {
        require(_mintMode > 0, 'Minting disabled');
        require(_tokenMinted <= _mintSupply, 'Max minting supply reached');

        // token id starts from index 0
        _mint(_to, _tokenMinted);
        unchecked {
          _tokenMinted += 1;
        }
    }

    // Minting from claim contract
    function claimMint(address _to) 
        external 
        virtual 
    {
        require(_claimContract != address(0), "Linked claim contract is not set");
        require(_claimContract == _msgSenderERC4973(), "Caller is not claim contract");
        _runMint(_to);
    }

    // Public minting
    function publicMint() 
        external 
        virtual 
        callerIsUser 
    {
        if (_mintMode == 2) {
            require(_tokenContract != address(0), "Invalid token contract address with zero address");
            require(soulData.getERC721Balance(_tokenContract, _msgSenderERC4973()) > 0, "Caller is not a target token owner");
        }
        _runMint(_msgSenderERC4973());
    }

    // Minting with signature from contract EIP712 signer
    function whitelistMint(bytes calldata _signature) 
        external 
        virtual 
        callerIsUser 
        checkWhitelist(_signature) 
    {
        _runMint(_msgSenderERC4973());
    }

    function burn(uint256 _tokenId) public virtual override {
      super.burn(_tokenId);
      unchecked {
          _tokenBurned += 1;
      }
    }

    // Set custom name on token image svg
    function setTokenCustomName(uint256 _tokenId, string calldata _name) external virtual {
        require(ownerOf(_tokenId) == _msgSenderERC4973(), "Caller is not token owner");
        require(bytes(_name).length < 23, "Custom name with invalid length");
        require(soulData.isValidCustomNameFormat(_name), "Custom name with invalid format");
        tokenCustomNames[_tokenId] = _name;
    }

    // Returns token creation timestamp
    function _tokenCreationTime(uint256 _tokenId) internal view virtual returns (uint256) {
        return uint256(_addressData[_ownerOf(_tokenId)].createTimestamp);
    }

    // Returns token info by address
    function tokenAddressInfo(address _owner) external virtual view returns (AddressData memory) {
        return _addressData[_owner];
    }

    /**
     * @dev Token SVG image and metadata is 100% on-chain generated (connected with Soul Data utility contract).
     */
    function tokenURI(uint256 _tokenId) external virtual view override returns (string memory) {
        require(_exists(_tokenId), "Token URI query for nonexistent token");

        // Soul Data contract provided two render modes for tokenURI()
        // 0 : data:application/json;utf8,
        // 1 : data:application/json;base64,
        return soulData.tokenURI(_tokenId, _metaName, _metaDesc, tokenBadgeTraits(_tokenId), _tokenVotingScore(_tokenId), _tokenCreationTime(_tokenId), tokenCustomNames[_tokenId]);
    }

    /**
     * @dev Render `Badge` traits
     * @dev Make sure the registered badge contract `balanceOf()` or 
     * `balanceOfSoul()` gas fee is not high, otherwise `tokenURI()` may hit 
     * (read operation) gas limit and become unavailable to public.
     * 
     * Please unlink any high gas badge contract to avoid issues.
     */
    function tokenBadgeTraits(uint256 _tokenId) public virtual view returns (string memory) {
        string memory output = "";
        for (uint256 badgeIndex = 0; badgeIndex < badgeSettings.length; badgeIndex++) {
            output = string(abi.encodePacked(
                            output, 
                            soulData.getBadgeTrait(
                              badgeSettings[badgeIndex].contractAddress, 
                              badgeIndex, 
                              address(this), 
                              _tokenId, 
                              ownerOf(_tokenId))
                            ));
        }
        return output;
    }
}