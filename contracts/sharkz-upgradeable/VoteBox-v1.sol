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
 * VoteBox - Sharkz genesis voting system
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../lib/sharkz/vote/IVoteBox.sol";
import "../lib/sharkz/IScore.sol";
import "../lib-upgradeable/sharkz/AdminableUpgradeable.sol";
import "../lib-upgradeable/712/EIP712VoteAllowlistUpgradeable.sol";

interface IBalanceOf {
  function balanceOf(address owner) external view returns (uint256 balance);
}

contract VoteBoxV1 is IVoteBox, Initializable, UUPSUpgradeable, AdminableUpgradeable, EIP712VoteAllowlistUpgradeable {
    // Implementation version number
    function version() external pure virtual returns (string memory) { return "1"; }

    // Struct to store each poll option name and vote count
    struct PollOption {
        // votion option name
        string name;
        // total vote count
        uint256 vote;
    }

    // Struct to store each voter address voting score and option
    struct AddressVote {
        // vote option
        uint128 voteOption;
        // score is calculated and fixed after voter casted a vote
        uint128 score;
    }

    struct PollSettings {
        uint40 startTime;
        uint40 endTime;
        bool disableChange;
        bool onlyAllowlist;
        bool onlyTokenHolder;
        bool disableScore;
    }

    // Poll object
    struct Poll {
        string topic;
        string content;

        // Compiler should pack below vars in uint256 space
        uint16 optionCount;
        uint40 startTime;
        uint40 endTime;
        address tokenContract;

        // Compiler should pack below vars in uint256 space
        uint8 disableChange;
        uint8 onlyAllowlist;
        uint8 onlyTokenHolder;
        uint8 disableScore;
        address scoreContract;
        
        // keep track of each vote option data
        mapping(uint256 => PollOption) options;
        // keep track of each voter address
        mapping(uint256 => address) addresses;
        // keep track of each voter address voting option and score
        mapping(address => AddressVote) addressVote;
    }

    // Total poll count, also represent next poll id
    uint256 public pollCount;

    // All poll objects
    mapping(uint256 => Poll) public polls;

    // Init this upgradeable contract
    function initialize() public initializer onlyProxy {
        __Adminable_init();
        __EIP712VoteAllowlist_init();
    }

    // Only admins can upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    // Check if a poll id exist
    modifier existsPoll(uint256 _pid) {
        require(_existsPoll(_pid), "Voting topic is not existed");
        _;
    }

    //////// Admin-only functions ////////
    // Create new poll by contract owner
    function createPoll(
        string calldata _topic,
        string calldata _content,
        uint16 _optionCount,
        uint40 _startTime,
        uint40 _endTime,
        uint8 _disableChange,
        uint8 _onlyAllowlist,
        uint8 _onlyTokenHolder,
        uint8 _disableScore
    ) 
        external 
        onlyAdmin 
        onlyProxy 
    {
        require(bytes(_topic).length > 0, "Create poll without topic");
        require(_optionCount > 0, "Create poll without option");
        require(_disableChange == 0 || _disableChange == 1, "Create poll with invalid disableChange");
        require(_onlyAllowlist == 0 || _onlyAllowlist == 1, "Create poll with invalid onlyAllowlist");
        require(_onlyTokenHolder == 0 || _onlyTokenHolder == 1, "Create poll with invalid onlyTokenHolder");
        require(_disableScore == 0 || _disableScore == 1, "Create poll with invalid disableScore");
        
        uint256 _pindex = pollCount;
        polls[_pindex].topic = _topic;
        polls[_pindex].content = _content;
        polls[_pindex].startTime = _startTime;
        polls[_pindex].endTime = _endTime;
        polls[_pindex].optionCount = _optionCount;
        polls[_pindex].disableChange = _disableChange;
        polls[_pindex].onlyAllowlist = _onlyAllowlist;
        polls[_pindex].onlyTokenHolder = _onlyTokenHolder;
        polls[_pindex].disableScore = _disableScore;
        pollCount ++;

        emit PollCreated(_pindex, _topic);
    }

    // Update poll token contract
    function setPollTokenContract(uint256 _pid, address _contract)
        external
        existsPoll(_pid)
        onlyAdmin
    {
        polls[_pid].tokenContract = _contract;
    }
    
    // Update poll score contract
    function setPollScoreContract(uint256 _pid, address _contract)
        external
        existsPoll(_pid)
        onlyAdmin
    {
        polls[_pid].scoreContract = _contract;
    }

    // Update poll content
    function setPollContent(uint256 _pid, string calldata _content) 
        external 
        existsPoll(_pid)
        onlyAdmin
    {
        polls[_pid].content = _content;
    }

    // Update poll option name
    function setPollOptionName(uint256 _pid, uint256 _option, string calldata _name) 
        external 
        existsPoll(_pid) 
        onlyAdmin 
    {
        require(_existsPollOption(_pid, _option), "Set option name for non-existing option");
        polls[_pid].options[_option].name = _name;
    }

    // Schedule poll with start time
    function setPollStartTime(uint256 _pid, uint40 _time) 
        external 
        existsPoll(_pid)
        onlyAdmin 
    {
        polls[_pid].startTime = _time;

        emit PollChangedStartTime(_pid, _time);
    }

    // Schedule poll ending time
    function setPollEndTime(uint256 _pid, uint40 _time) 
        external 
        existsPoll(_pid) 
        onlyAdmin 
    {
        polls[_pid].endTime = _time;

        emit PollChangedEndTime(_pid, _time);
    }

    //////// End of Admin-only functions ////////

    // Do not allow contract to call
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    // Submit or change vote
    function vote(uint256 _pid, uint256 _value, bytes calldata _signature) 
        external 
        callerIsUser 
        existsPoll(_pid) 
        onlyProxy 
    {
        address voterAddr = msg.sender;
        require(voterAddr != address(0), "Voter is zero address");
        // poll option starts from 1 ~ n (poll optionCount)
        require(_existsPollOption(_pid, _value), "Vote for non-existing option");
        require(isPollStarted(_pid), "Vote is not started");
        require(isVoterAllowed(_pid, _signature), "Voter is not allowed");
        require(isVoterTokenOwner(_pid, voterAddr), "Voter is not target token owner");

        // voter index starts at 0, next voter index will be the current vote count
        uint256 voterIndex = _getPollVoteCount(_pid);

        unchecked {
            if (!_existsVote(_pid, voterAddr)) {
                // first-time record new voter address and vote value
                polls[_pid].addresses[voterIndex] = voterAddr;
                polls[_pid].options[_value].vote ++;
            } else {
                // changing vote
                require(polls[_pid].disableChange == 0, "Vote change is disabled");
                uint256 previousVote = _getAddressVote(_pid, voterAddr);
                if (_value != previousVote) {
                    // changing previous vote
                    polls[_pid].options[previousVote].vote --;
                    polls[_pid].options[_value].vote ++;
                }
            }
        }

        // Update vote option and score
        AddressVote memory addrVote;
        addrVote.voteOption = uint128(_value);
        addrVote.score = uint128(_getVoterScore(polls[_pid].scoreContract, voterAddr));
        polls[_pid].addressVote[voterAddr] = addrVote;

        emit Voted(voterAddr, _pid, _value);
    }
    
    ////////// External functions
    // Get poll content url
    function totalPoll() external view override returns (uint256) {
        return pollCount;
    }

    // Get poll settings
    function getPollSettings(uint256 _pid) external view returns (PollSettings memory settings) {
        settings.startTime = polls[_pid].startTime;
        settings.endTime = polls[_pid].endTime;
        settings.disableChange = polls[_pid].disableChange > 0;
        settings.onlyAllowlist = polls[_pid].onlyAllowlist > 0;
        settings.onlyTokenHolder = polls[_pid].onlyTokenHolder > 0;
        settings.disableScore = polls[_pid].disableScore > 0;
    }

    // Get poll start time
    function getPollStartTime(uint256 _pid) external view override returns (uint256) {
        return polls[_pid].startTime;
    }

    // Get poll end time
    function getPollEndTime(uint256 _pid) external view override returns (uint256) {
        return polls[_pid].endTime;
    }

    // Get poll available option count
    function getPollOptionCount(uint256 _pid) external view override existsPoll(_pid) returns (uint256) {
        return polls[_pid].optionCount;
    }

    // Get poll topic
    function getPollTopic(uint256 _pid) external view override existsPoll(_pid) returns (string memory) {
        return polls[_pid].topic;
    }

    // Get poll content url
    function getPollContent(uint256 _pid) external view override existsPoll(_pid) returns (string memory) {
        return polls[_pid].content;
    }

    // Get poll option name
    function getPollOptionName(uint256 _pid, uint256 _option) external view override existsPoll(_pid) returns (string memory) {
        require(_existsPollOption(_pid, _option), "Non-existing vote option");
        return polls[_pid].options[_option].name;
    }

    // Get poll total vote counts
    function getPollTotalVoteCount(uint256 _pid) external view override existsPoll(_pid) returns (uint256) {
        return _getPollVoteCount(_pid);
    }

    // Get poll total vote counts
    function getPollTotalScore(uint256 _pid) external view override existsPoll(_pid) returns (uint256) {
        uint256 totalVote = _getPollVoteCount(_pid);
        uint8 disableScore = polls[_pid].disableScore;
        uint256 score;
        address voterAddr;
        uint256 i;
        // Avoid max uint checking since it is unlikely to hit 2**256-1
        unchecked {
            while (i < totalVote) {
                voterAddr = polls[_pid].addresses[i];
                if (disableScore == 0) {
                    score += _getAddressScore(_pid, voterAddr);
                } else {
                    // just count one score per vote
                    score += 1;
                }
                i += 1;
            }
        }
        return score;
    }

    // Get poll total vote count for an option
    function getPollOptionVoteCount(uint256 _pid, uint256 _option) external view override existsPoll(_pid) returns (uint256) {
        require(_existsPollOption(_pid, _option), "Non-existing vote option");
        return _getPollOptionVoteCount(_pid, _option);
    }

    // Get poll total score for an option
    function getPollOptionScore(uint256 _pid, uint256 _option) external view override existsPoll(_pid) returns (uint256) {
        uint256 totalVote = _getPollVoteCount(_pid);
        uint8 disableScore = polls[_pid].disableScore;
        uint256 score;
        address voterAddr;
        uint256 i;
        // Avoid max uint checking since it is unlikely to hit 2**256-1
        unchecked {
            while (i < totalVote) {
                voterAddr = polls[_pid].addresses[i];
                if (_getAddressVote(_pid, voterAddr) == _option) {
                    if (disableScore == 0) {
                        score += _getAddressScore(_pid, voterAddr);
                    } else {
                        // just count one score per vote
                        score += 1;
                    }
                }
                i += 1;
            }
        }
        return score;
    }

    // Get voter vote value for a poll
    function getAddressVote(uint256 _pid, address _addr) external view override existsPoll(_pid) returns (uint256) {        
        uint256 value = _getAddressVote(_pid, _addr);
        require(value != 0, "Vote not found");

        return value;
    }

    // Get voter address by poll id and voter index
    function getVoterAddress(uint256 _pid, uint256 _voterIndex) external view override existsPoll(_pid) returns (address) {
        address voterAddr = polls[_pid].addresses[_voterIndex];
        require(voterAddr != address(0), "Voter not found");

        return voterAddr;
    }

    // Check if a poll is started and not ended
    function isPollStarted(uint256 _pid) public view override existsPoll(_pid) returns (bool) {
        uint256 startTime = polls[_pid].startTime;
        uint256 endTime = polls[_pid].endTime;
        uint256 blockTime = block.timestamp;

        return startTime > 0 && blockTime >= startTime && blockTime < endTime;
    }

    // Check voter is on poll allowlist
    function isVoterAllowed(uint256 _pid, bytes calldata _signature) public view override existsPoll(_pid) returns (bool) {
        // by default, this will return true when unset or 0 value
        if (polls[_pid].onlyAllowlist == 0) {
            return true;
        }
        return verifySignature(_signature, _pid);
    }

    // Check if voter is currently owner of required NFT
    function isVoterTokenOwner(uint256 _pid, address _addr) public view override existsPoll(_pid) returns (bool) {
        // when poll onlyTokenHolder is disabled, skipping nft holder checking
        if (polls[_pid].onlyTokenHolder == 0) return true;

        address tokenContract = polls[_pid].tokenContract;
        require(tokenContract != address(0), "Non-existing token contract");

        return _isExternalTokenOwner(tokenContract, _addr);
    }


    ////////// Internal functions
    // Returns whether poll id exists.
    function _existsPoll(uint256 _pid) internal view returns (bool) {
        return _pid < pollCount;
    }

    // Returns whether poll option exists.
    function _existsPollOption(uint256 _pid, uint256 _option) internal view returns (bool) {
        return _option > 0 && _option <= polls[_pid].optionCount;
    }

    // Returns whether address has existing vote
    function _existsVote(uint256 _pid, address _addr) internal view returns (bool) {
        return uint256(polls[_pid].addressVote[_addr].voteOption) != 0;
    }

    // Returns the vote value for a voter address
    function _getAddressVote(uint256 _pid, address _addr) internal view returns (uint256) {
        return uint256(polls[_pid].addressVote[_addr].voteOption);
    }

    // Returns the score for a voter address
    function _getAddressScore(uint256 _pid, address _addr) internal view returns (uint256) {
        return uint256(polls[_pid].addressVote[_addr].score);
    }

    // Returns the total vote count for a poll
    function _getPollVoteCount(uint256 _pid) internal view returns (uint256) {
        // optionCount must be larger than 0
        uint256 optionCount = polls[_pid].optionCount;

        uint256 index = 1;
        uint256 count = 0;
        do {
            count += polls[_pid].options[index].vote;
            index ++;
        }
        while (index <= optionCount);

        return count;
    }

    // Returns the total vote count for a poll option
    function _getPollOptionVoteCount(uint256 _pid, uint256 _option) internal view returns (uint256) {
        return polls[_pid].options[_option].vote;
    }

    // Returns whether an address is NFT owner
    function _isExternalTokenOwner(address _tokenContract, address _ownerAddress) internal view returns (bool) {
        try IBalanceOf(_tokenContract).balanceOf(_ownerAddress) returns (uint256 balance) {
            return balance > 0;
        } catch (bytes memory) {
            // when reverted, just returns...
            return false;
        }
    }

    // Returns the score from external token contract for an owner address
    function _getVoterScore(address _scoreContract, address _ownerAddress) internal view returns (uint256) {
        if (_scoreContract == address(0)) {
            return 1;
        }

        try IScore(_scoreContract).scoreByAddress(_ownerAddress) returns (uint256 score) {
            return score;
        } catch (bytes memory) {
            // when reverted, just returns...
            return 1;
        }
    }
}