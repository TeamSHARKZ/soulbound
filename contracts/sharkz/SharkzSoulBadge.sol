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
 * Sharkz Soul Badge
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../lib/sharkz/IScore.sol";
import "../lib/sharkz/Adminable.sol";
import "../lib/5114/ERC5114SoulBadge.sol";
import "../lib/712/EIP712Whitelist.sol";

interface IBalanceOf {
    function balanceOf(address owner) external view returns (uint256 balance);
}

interface IVoter {
    // Get voter vote value for a poll
    function getAddressVote(uint256 _pid, address _addr) external view returns (uint256);
}

contract SharkzSoulBadge is IScore, Adminable, ReentrancyGuard, EIP712Whitelist, ERC5114SoulBadge {
    // Keep track of total minted token count
    uint256 public tokenMinted;

    // Mint modes, 0: disable-minting, 1: free-mint, 2: restrict minting to target token owner, 3: restrict to voter
    uint256 public mintMode;

    // Max mint supply
    uint256 public mintSupply;
    
    // Target token contract for limited minting
    address public tokenContract;

    // Target voting contract for limited minting
    address public voteContract;

    // Target voting poll Id for limited minting
    uint256 public votePollId;

    // Minting by claim contract
    address internal _claimContract;

    // Token image (all token use same image)
    string public tokenImageUri;

    constructor(string memory _name, string memory _symbol, string memory _collectionUri, string memory _tokenImageUri) 
        ERC5114SoulBadge(_name, _symbol, _collectionUri, "") 
        EIP712Whitelist() 
    {
        tokenImageUri = _tokenImageUri;
        // default mint supply 10k
        mintSupply = 10000;
    }

    /**
     * @dev {IERC5114-tokenUri} alias to tokenURI(), so we just override tokenURI()
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Non-existent token");

        string memory output = string(abi.encodePacked(
          '{"name":"', name, ' #', _toString(tokenId), '","image":"', tokenImageUri, '"}'
        ));
        return string(abi.encodePacked("data:application/json;utf8,", output));
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) || 
               interfaceId == type(IScore).interfaceId;
    }

    /**
     * @dev See {IScore-baseScore}.
     */
    function baseScore() public pure virtual override returns (uint256) {
        return 1;
    }

    /**
     * @dev See {IScore-scoreByToken}.
     */
    function scoreByToken(uint256 _tokenId) external view virtual override returns (uint256) {
        if (_exists(_tokenId)) {
          return 1;
        } else {
          return 0;
        }
    }

    /**
     * @dev See {IScore-scoreByAddress}.
     */
    function scoreByAddress(address _addr) external view virtual override returns (uint256) {
        require(_addr != address(0), "Address is the zero address");
        revert("score by address not supported");
    }

    // Caller must not be an wallet account
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "Caller should not be a contract");
        _;
    }

    // Caller must be `Soul` token owner
    modifier callerIsSoulOwner(address soulContract, uint256 soulTokenId) {
        require(soulContract != address(0), "Soul contract is the zero address");
        require(msg.sender == _getSoulOwnerAddress(soulContract, soulTokenId), "Caller is not Soul token owner");
        _;
    }

    // Change minting mode
    function setMintMode(uint256 _mode) external virtual onlyAdmin {
        mintMode = _mode;
    }

    // Change mint supply
    function setMintSupply(uint256 _max) external virtual onlyAdmin {
        mintSupply = _max;
    }

    // Update linking IBalanceOf contract address
    function setMintRestrictContract(address _addr) external onlyAdmin {
        tokenContract = _addr;
    }

    // Update linking vote contract and poll Id
    function setMintRestrictVote(address _addr, uint256 _pid) external onlyAdmin {
        voteContract = _addr;
        votePollId = _pid;
    }

    // Update linking claim contract
    function setClaimContract(address _addr) external onlyAdmin {
        _claimContract = _addr;
    }

    // Returns total valid token count
    function totalSupply() public view returns (uint256) {
        return tokenMinted;
    }

    // Create a new token for Soul
    function _runMint(address soulContract, uint256 soulTokenId) private nonReentrant {
        require(mintMode > 0, 'Minting disabled');
        require(tokenMinted < mintSupply, 'Max minting supply reached');

        // mint to Soul contract and Soul tokenId
        _mint(tokenMinted, soulContract, soulTokenId);
        unchecked {
          tokenMinted += 1;
        }
    }

    // Minting by admin to any address
    function ownerMint(address soulContract, uint256 soulTokenId) 
        external 
        onlyAdmin 
    {
        _runMint(soulContract, soulTokenId);
    }

    // Minting from claim contract
    function claimMint(address soulContract, uint256 soulTokenId) external {
        require(_claimContract != address(0), "Linked claim contract is not set");
        require(_claimContract == msg.sender, "Caller is not claim contract");
        _runMint(soulContract, soulTokenId);
    }

    // Public minting, limited to Soul Token owner
    function publicMint(address soulContract, uint256 soulTokenId) 
        external 
        callerIsUser() 
        callerIsSoulOwner(soulContract, soulTokenId)
    {
        if (mintMode == 2) {
            // target token owner
            require(tokenContract != address(0), "Token contract is the zero address");
            require(_isExternalTokenOwner(tokenContract, msg.sender), "Caller is not target token owner");
        }
        if (mintMode == 3) {
            // target poll voter
            require(voteContract != address(0), "Vote contract is the zero address");
            require(isVoter(voteContract, votePollId, msg.sender), "Caller is not voter");
        }
        _runMint(soulContract, soulTokenId);
    }

    // Minting with signature from contract EIP712 signer, limited to Soul Token owner
    function whitelistMint(bytes calldata _signature, address soulContract, uint256 soulTokenId) 
        external 
        checkWhitelist(_signature) 
        callerIsUser 
        callerIsSoulOwner(soulContract, soulTokenId)
    {
        _runMint(soulContract, soulTokenId);
    }

    /**
     * @dev Returns whether an address is NFT owner
     */
    function _isExternalTokenOwner(address _contract, address _ownerAddress) internal view returns (bool) {
        try IBalanceOf(_contract).balanceOf(_ownerAddress) returns (uint256 balance) {
            return balance > 0;
        } catch (bytes memory) {
          // when reverted, just returns...
          return false;
        }
    }

    /**
     * @dev Returns whether an address is a voter for a poll
     */
    function isVoter(address _contract, uint256 _pid, address _addr) public view returns (bool) {
        try IVoter(_contract).getAddressVote(_pid, _addr) returns (uint256 voteOption) {
            return voteOption > 0;
        } catch (bytes memory) {
          // when reverted, just returns...
          return false;
        }
    }
}