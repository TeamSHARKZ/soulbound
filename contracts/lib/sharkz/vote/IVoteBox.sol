// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * IVoteBox interface
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

interface IVoteBox {
    event PollCreated(uint256 indexed pollId, string topic);
    event PollChangedStartTime(uint256 indexed pollId, uint256 indexed time);
    event PollChangedEndTime(uint256 indexed pollId, uint256 indexed time);
    event Voted(address indexed sender, uint256 indexed pollId, uint256 value);

    // Get total poll count
    function totalPoll() external view returns (uint256);
    // Get poll start time
    function getPollStartTime(uint256 _pid) external view returns (uint256);
    // Get poll end time
    function getPollEndTime(uint256 _pid) external view returns (uint256);
    // Get poll content
    function getPollTopic(uint256 _pid) external view returns (string memory);
    // Get poll content
    function getPollContent(uint256 _pid) external view returns (string memory);
    // Get poll total options available
    function getPollOptionCount(uint256 _pid) external view returns (uint256);
    // Get poll option name
    function getPollOptionName(uint256 _pid, uint256 _option) external view returns (string memory);
    // Get poll total vote counts
    function getPollTotalVoteCount(uint256 _pid) external view returns (uint256);
    // Get poll total score
    function getPollTotalScore(uint256 _pid) external view returns (uint256);
    // Get poll total vote count for an option
    function getPollOptionVoteCount(uint256 _pid, uint256 _option) external view returns (uint256);
    // Get poll total score for an option
    function getPollOptionScore(uint256 _pid, uint256 _option) external view returns (uint256);
    // Get voter vote value for a poll
    function getAddressVote(uint256 _pid, address _addr) external view returns (uint256);
    // Get voter address by poll id and voter index
    function getVoterAddress(uint256 _pid, uint256 _voterIndex) external view returns (address);
    // Check if a poll is started and not ended
    function isPollStarted(uint256 _pid) external view returns (bool);
    // Check voter is on poll allowlist
    function isVoterAllowed(uint256 _pid, bytes calldata _signature) external view returns (bool);
    // Check voter is poll targeted nft holder
    function isVoterTokenOwner(uint256 _pid, address _addr) external returns (bool);
}