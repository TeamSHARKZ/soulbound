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
 * LuckyBox - A raffle drawer for a pool of ids
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../lib/sharkz/vote/IVoteBox.sol";
import "../lib/sharkz/Adminable.sol";

/**
 * @dev Lucky draw facility designed to connect with VoteBox contract, random seeded 
 *  provided by requesting Chainlink VRF for RNG seeding.
 *  
 *  Steps to start a new draw event:
 *  1) Admin calls createDraw() to setup next draw event, each draw event may 
 *     (optionally) link to an external contract, mapping winner ids to wallet 
 *      addresses.
 *  2) Admin calls setDrawProvenance(draw_id, proof) to set the proof hash for 
 *     the (unique) wallet sequence, the sequencial index is then the lucky draw
 *     ticket id mapping to each wallet address.
 *  3) Admin calls draw() to request Chainlink random seed for the next draw event, 
 *     after seeding is done, the draw result is revealed.
 *  4) All users can query getWinnerByIndex(draw_id, winner_index) to see each winner
 *     by winner_index. eg.
 *     Draw #7, #1 1st winner: getWinnerByIndex(7, 0) = wallet #0xef645930efbf6f4dc2712c9df2e3acd28c51273c
 *     Draw #7, #2 2nd winner: getWinnerByIndex(7, 1) = wallet #0x3d223afcb04123ad140faa25eac21af4faa9a27e
 *     Draw #7, #3 3rd winner: getWinnerByIndex(7, 2) = wallet #0x165CD37b4C644C2921454427A7F9358d18A45e14
 *
 */
contract LuckyBox is Adminable, VRFConsumerBaseV2, ReentrancyGuard {
    event DrawCreated(uint256 indexed index, string topic, string content, uint64 poolSize, uint64 winnerSize, uint64 drawTime, uint256 indexed voteBoxPollId, address indexed voteBoxContract);
    event DrawSeeded(uint256 indexed index, uint256 randomSeed);

    // Chainlink VRF, https://docs.chain.link/docs/vrf-contracts/#configurations
    struct VRFRequestConfig {
        uint64 subId;
        uint32 reqGasLimit;
        uint16 reqConfirmations;
    }
    VRFRequestConfig public vrfConfig;
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    address vrfCoordinator;
    address vrfLinkContract;
    bytes32 vrfKeyHash;
    uint256 public vrfRequestId;

    struct DrawEvent {
        // draw topic name
        string topic;
        // draw content ipfs or link to the content
        string content;
        // hash proof of the ids to wallet mapping data
        string provenance;
        // the pool of all ids
        uint64 poolSize;
        // the pool size for winners
        uint64 winnerSize;
        // reveal the result only after block time is after draw time
        uint64 drawTime;
        // if voting contract poll id is non-zero, enable checking votebox voter address directly
        uint64 voteBoxPollId;
        // linking voting contract (if the draw need to link VoteBox contract)
        IVoteBox voteBoxContract;
    }
    // all draw events
    mapping(uint256 => DrawEvent) public drawEvents;
    // draw seeds
    mapping(uint256 => uint256) private _drawSeeds;
    // total draw event counter, also the next event index id
    uint256 public eventCount;
    // total seeded event counter, also the next seedding event index id
    uint256 public seededEventCount;

    constructor () VRFConsumerBaseV2(vrfCoordinator) {
        // VRF setup (Chainlink Goerli)
        vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
        vrfLinkContract = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        vrfKeyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(vrfLinkContract);
        vrfConfig = VRFRequestConfig({
            subId: 10943,
            reqGasLimit: 2500000,
            reqConfirmations: 3
        });
    }

    // @@@@@@@@@@TESTONLY
    function testDraw(uint256 _randomSeed) external onlyAdmin {
        _seed(_randomSeed);
    }

    function createDraw(
        string calldata _topic, 
        string calldata _content, 
        uint64 _poolSize,
        uint64 _winnerSize,
        uint64 _drawTime,
        uint64 _voteBoxPollId,
        address _voteBoxContract
    ) external onlyAdmin {
        require(bytes(_topic).length > 0, "Topic is empty");
        require(_poolSize > 0, "Pool size is zero");
        require(_winnerSize > 0, "Winner size is zero");
        require(_drawTime > 0, "Draw time is zero");

        uint256 _i = eventCount;
        drawEvents[_i].topic = _topic;
        drawEvents[_i].content = _content;
        drawEvents[_i].poolSize = _poolSize;
        drawEvents[_i].winnerSize = _winnerSize;
        drawEvents[_i].drawTime = _drawTime;
        drawEvents[_i].voteBoxPollId = _voteBoxPollId;
        drawEvents[_i].voteBoxContract = IVoteBox(_voteBoxContract);
        eventCount++;

        emit DrawCreated(_i, _topic, _content, _poolSize, _winnerSize, _drawTime, _voteBoxPollId, _voteBoxContract);
    }

    // Calculate prevenance hash with the draw participants' addresses sequence, participants index start from 0
    function setDrawProvenance(uint256 _drawIndex, string memory _proof) external onlyAdmin {
        require(bytes(drawEvents[_drawIndex].provenance).length == 0, "Draw provenance already setup");
        drawEvents[_drawIndex].provenance = _proof;
    }

    // Run next lucky draw (Lucky draw seed will be filled by Chainlink VRF service)
    function draw() external nonReentrant onlyAdmin {
        require (eventCount > seededEventCount, "No pending draw event");

        VRFRequestConfig memory vrf = vrfConfig;
        vrfRequestId = COORDINATOR.requestRandomWords(
            vrfKeyHash,
            vrf.subId,
            vrf.reqConfirmations,
            vrf.reqGasLimit,
            1
        );
    }

    // change draw event VoteBox contract link
    function setVoteBoxData(uint256 _drawIndex, address _voteBoxContract, uint256 _pid) external onlyAdmin{
        require(_existsDraw(_drawIndex), "Draw is not exists");
        require(_voteBoxContract != address(0), "Invalid contract address");
        require(_pid > 0, "Invalid VoteBox poll id");

        drawEvents[_drawIndex].voteBoxContract = IVoteBox(_voteBoxContract);
        drawEvents[_drawIndex].voteBoxPollId = uint64(_pid);
    }

    // get an array of all winner ids
    function getAllWinners(uint256 _drawIndex) public view returns (uint256[] memory) {
        require(_existsDraw(_drawIndex), "Draw is not exists");
        require(_isDrawSeeded(_drawIndex), "Draw is not seeded");

        uint256 drawTime = uint256(drawEvents[_drawIndex].drawTime);
        require(drawTime > 0 && block.timestamp > drawTime, "Draw time is not reached");

        uint256 seed = _drawSeeds[_drawIndex];
        require(seed > 0, "Draw is not seeded");

        // create sequential id pool
        uint256 poolSize = drawEvents[_drawIndex].poolSize;
        uint256[] memory ids = new uint256[](poolSize + 1);
        for (uint256 i = 0; i < poolSize; i++) {
            ids[i] = i;
        }
        
        // shuffle the pool
        for (uint256 i = 0; i < poolSize; i++) {
            uint256 swap = uint256(keccak256(abi.encode(seed,i))) % poolSize;
            (ids[i], ids[swap]) = (ids[swap], ids[i]);
        }

        // generate winner pool
        // when total pool size is smaller than target winner pool size, everyone win!
        uint256 winnerSize = drawEvents[_drawIndex].winnerSize;
        if (poolSize < winnerSize) {
            winnerSize = poolSize;
        }

        // select winners one by one from start index in the shuffled pool
        uint256[] memory winnerIds = new uint256[](winnerSize);
        for (uint256 i = 0; i < winnerSize; i++) {
            winnerIds[i] = ids[i];
        }

        return winnerIds;
    }

    // get winners participants id, ex: winner index 0 is first-place winner, index 1 is second-place winner...
    function getWinnerByIndex(uint256 _drawIndex, uint256 _winnerIndex) external view returns (uint256) {
        require(_existsDraw(_drawIndex), "Draw is not exists");
        require(_isDrawSeeded(_drawIndex), "Draw is not seeded");

        uint256[] memory ids = getAllWinners(_drawIndex);
        return ids[_winnerIndex];
    }

    // get winner voter address (available if draw linked to VoteBox contract) for a draw event with winner index
    function getWinnerVoterAddress(uint256 _drawIndex, uint256 _winnerIndex) external view returns (address) {
        require(_existsDraw(_drawIndex), "Draw is not exists");
        require(_isDrawSeeded(_drawIndex), "Draw is not seeded");

        uint256[] memory ids = getAllWinners(_drawIndex);
        uint256 voterIndex = ids[_winnerIndex];

        // call external contract
        IVoteBox voteBox = drawEvents[_drawIndex].voteBoxContract;
        uint256 pid = drawEvents[_drawIndex].voteBoxPollId;

        return voteBox.getVoterAddress(pid, voterIndex);
    }

    ///////// Internal functions
    // Check if draw event exists
    function _existsDraw(uint256 _drawIndex) internal view returns (bool) {
        return _drawIndex < eventCount;
    }

    // Check if draw event seeded (finished raffle draw)
    function _isDrawSeeded(uint256 _drawIndex) internal view returns (bool) {
        return _drawSeeds[_drawIndex] > 0;
    }

    // Insert the new seed to the last unseeded draw event
    function _seed(uint256 _randomSeed) internal {
        require (seededEventCount < eventCount, "All draws are seeded");

        // setup the random seed for next draw event (reveal winners)
        uint256 _drawIndex = seededEventCount;
        _drawSeeds[_drawIndex] = _randomSeed;
        emit DrawSeeded(_drawIndex, _randomSeed);

        seededEventCount++;
    }

    // Chainlink VRF Coordinator will call this internal function via rawFulfillRandomWords() public function
    function fulfillRandomWords(uint256 _reqId, uint256[] memory _randomWords) internal override {
        require(_reqId == vrfRequestId, "Invalid VRF request id");

        if (_randomWords[0] > 0) {
            _seed(_randomWords[0]);
        }
    }
    
    // Chainlink VRF change subscription Id
    function changeVRFSubId(uint64 _subId) external onlyAdmin {
        vrfConfig.subId = _subId;
    }

    // Chainlink VRF change Coordinator contract address
    function changeVRFCoordinator(address _contractAddr) external onlyAdmin {
        vrfCoordinator = _contractAddr;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    }

    // Chainlink VRF change LINK token contract address
    function changeVRFLinkToken(address _contractAddr) external onlyAdmin {
        vrfLinkContract = _contractAddr;
        LINKTOKEN = LinkTokenInterface(vrfLinkContract);
    }
    
    // Chainlink VRF change key hash
    function changeVRFKeyHash(bytes32 _keyHash) external onlyAdmin {
        vrfKeyHash = _keyHash;
    }
}
