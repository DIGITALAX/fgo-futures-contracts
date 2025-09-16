// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;
import "./FGOFuturesErrors.sol";

contract FGOFuturesAccessControl {
    string public symbol;
    string public name;
    bool public adminControlRevoked;
    address public monaToken;

    mapping(address => bool) private _admins;

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event AdminRevoked();
    event MonaTokenUpdated(address indexed oldToken, address indexed newToken);

    modifier onlyAdmin() {
        if (adminControlRevoked) {
            revert FGOFuturesErrors.Unauthorized();
        }
        if (!_admins[msg.sender]) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    constructor(address _monaToken) {
        _admins[msg.sender] = true;
        monaToken = _monaToken;
        symbol = "FGOFAC";
        name = "FGOFuturesAccessControl";
    }

    function addAdmin(address admin) external onlyAdmin {
        if (_admins[admin]) {
            revert FGOFuturesErrors.AlreadyExists();
        }
        _admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external onlyAdmin {
        if (admin == msg.sender) {
            revert FGOFuturesErrors.CantRemoveSelf();
        }
        if (!_admins[admin]) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function isAdmin(address _address) public view returns (bool) {
        return _admins[_address];
    }

    function revokeAdminControl() external onlyAdmin {
        adminControlRevoked = true;
        emit AdminRevoked();
    }

    function setMonaToken(address _monaToken) external onlyAdmin {
        address oldToken = monaToken;
        monaToken = _monaToken;
        emit MonaTokenUpdated(oldToken, _monaToken);
    }
}
