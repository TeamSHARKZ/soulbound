// SPDX-License-Identifier: MIT

/**
 *******************************************************************************
 * Contract Test
 *******************************************************************************
 * Author: Jason Hoi
 *
 */
pragma solidity ^0.8.7;

// Just to test admin and payable
contract ContractTest {
    event TxOrigin(address indexed addr);
    event MsgSender(address indexed addr);

    event PublicMint(address indexed addr, uint256 indexed qty, uint256 indexed value);
    event Deposit(address indexed addr, uint256 indexed value);
    event Withdraw(address indexed to, uint256 indexed value, address indexed caller);
    event AdminCreated(address indexed addr);
    event AdminRemoved(address indexed addr);

    uint256 mintPrice = 0.001 ether;
    uint256 anyValue;

    // mapping for admin address
    mapping(address => uint256) _admins;

    // add the first admin with contract creator
    constructor() {
        _admins[msgSender()] = 1;
    }

    modifier onlyAdmin() {
        require(isAdmin(msgSender()), "Adminable: caller is not admin");
        _;
    }

    function isAdmin(address addr) public view virtual returns (bool) {
        return _admins[addr] == 1;
    }

    function setAdmin(address to, bool approved) public virtual onlyAdmin {
        require(to != address(0), "Adminable: cannot set admin for the zero address");

        if (approved) {
            require(!isAdmin(to), "Adminable: add existing admin");
            _admins[to] = 1;
            emit AdminCreated(to);
        } else {
            require(isAdmin(to), "Adminable: remove non-existent admin");
            delete _admins[to];
            emit AdminRemoved(to);
        }
    }

    function getTxOrigin(uint256 _any) public view virtual returns (address) {
        require(_any > 0 || _any <= 0, 'must be any value');
        return tx.origin;
    }

    function getMsgSender(uint256 _any) external view returns (address) {
        require(_any > 0 || _any <= 0, 'must be any value');
        return msg.sender;
    }

    function emitTxOrigin(uint256 _anyValue) external {
        require(_anyValue > 0, 'just input more than 0');
        emit TxOrigin(tx.origin);
    }

    function emitMsgSender(uint256 _anyValue) external {
        require(_anyValue > 0, 'just input more than 0');
        emit MsgSender(msg.sender);
    }

    function msgSender() public view returns (address) {
        return msg.sender;
    }

    function publicMint(uint256 _qty) external payable
    {
        uint256 value = mintPrice * _qty;
        require(msg.value >= value, "Need to send more ether");
        emit PublicMint(msgSender(), _qty, value);
    }

    function deposit() external payable {
        require(msg.value >= 0, "Must input some base token");      
        emit Deposit(msgSender(), msg.value);
    }

    function withdraw(address payable _to) public onlyAdmin {
        // Call returns a boolean value indicating success or failure.
        uint256 balance = address(this).balance;
        (bool success, ) = _to.call{value: balance}("");
        require(success, "Withdraw failed");
        emit Withdraw(_to, balance, msgSender());
    }
}