// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenMock is ERC20, IToken {
    bool private wasBurnDistributorTokensAndUnlockCalled;

    constructor(address _beneficiary, uint256 _amount) public ERC20("TokenMock", "TokenMock") {
        _mint(_beneficiary, _amount);
    }

    function uniswapPairAddress() external view override returns (address) {
        return address(0);
    }

    function setUniswapPair(address _uniswapPair) external override {}

    function burnDistributorTokensAndUnlockShouldBeCalled() external view {
        require(wasBurnDistributorTokensAndUnlockCalled, "burnDistributorTokensAndUnlock function was not called.");
    }

    function burnDistributorTokensAndUnlock() external override {
        wasBurnDistributorTokensAndUnlockCalled = true;
    }
}
