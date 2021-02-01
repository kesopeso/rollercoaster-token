// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenMock is ERC20, IToken {
    bool private shouldCompareBurn;
    uint256 private burnAmount;
    bool private wasUnlockCalled;

    constructor(address _beneficiary, uint256 _amount) public ERC20("TokenMock", "TokenMock") {
        _mint(_beneficiary, _amount);
    }

    function unlockShouldBeCalled() external view {
        require(wasUnlockCalled, "Unlock was not called.");
    }

    function unlock() external override {
        wasUnlockCalled = true;
    }

    function isUnlocked() external override returns (bool) {
        return wasUnlockCalled;
    }

    function burnShouldReceive(uint256 _amount) external {
        shouldCompareBurn = true;
        burnAmount = _amount;
    }

    function burn(uint256 _amount) external override {
        if (shouldCompareBurn) {
            require(burnAmount == _amount, "_amount parameter missmatch.");
        }
    }
}
