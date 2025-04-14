// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * Packed data test
 *******************************************************************************
 * Creator: Sharkz Entertainment
 * Author: Jason Hoi
 *
 */

pragma solidity ^0.8.7;

contract PackedData {

    struct PollSettings {
        uint40 startTime;
        uint40 endTime;
        bool disableChange;
        bool onlyAllowlist;
        bool onlyNftHolder;
        bool disableScore;
    }
    uint256 pollSettings;

    function packPollSettings(uint40 _startTime, uint40 _endTime, uint8 _disableChange, uint8 _onlyAllowlist, uint8 _onlyNftHolder, uint8 _disableScore) external 
    {
        pollSettings = _startTime + uint80(_endTime) * 2**40 + _disableChange*2**80 + _onlyAllowlist*2**88 + _onlyNftHolder*2**96 + _disableScore*2**104;
    }

    function unpackPollSettings() external view returns (PollSettings memory settings) {
        uint256 copy = pollSettings;
        
        settings.startTime = uint40(copy);
        settings.endTime = uint40(copy >> 40);
        settings.disableChange = uint8(copy >> 80 & 1) == 1;
        settings.onlyAllowlist = uint8(copy >> 88 & 1) == 1;
        settings.onlyNftHolder = uint8(copy >> 96 & 1) == 1;
        settings.disableScore = uint8(copy >> 104 & 1) == 1;
    }

  
    struct Data {
        uint40 time;
        uint8 x;
        uint8 y;
    }

    uint256 public data;

    function save(uint40 time, uint8 x, uint8 y) external {
        // Layout A
        // [1] y
        // [2] x
        // [3-42] time
        // data =  (time << 2) | x << 1 | y;

        // Layout B
        // [..40] time
        // [41] x
        // [42] y
        data = time + x * 2**40 + y * 2**48;
    }

    function getData() external view returns (Data memory settings) {
        // Layout A
        // settings.time = uint40(data >> 2);
        // settings.x = uint8(data >> 1 & 1);
        // settings.y = uint8(data & 1);

        // Layout B
        settings.time = uint40(data);
        settings.x = uint8(data >> 40 & 1);
        settings.y = uint8(data >> 41 & 1);
    }

    function getTime() external view returns (uint40) {
        // Layout A
        // return uint40(data >> 2);

        // Layout B
        return uint40(data);
    }

    function getX() external view returns (bool) {
        // Layout A
        // return uint8(data >> 1 & 1) == 1;

        // Layout B
        return uint8(data >> 40 & 1) == 1;
    }

    function getY() external view returns (bool) {
        // Layout A
        // return uint8(data & 1) == 1;

        // Layout B
        return uint8(data >> 41 & 1) == 1;
    }
}