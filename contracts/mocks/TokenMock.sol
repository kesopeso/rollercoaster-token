// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenMock is ERC20, IToken {
    constructor(address _beneficiary, uint256 _amount) public ERC20("TokenMock", "TokenMock") {
        _mint(_beneficiary, _amount);
    }

    function unlock() external override {}

    function isUnlocked() external override returns (bool) {
        return true;
    }

    function burn(uint256 _amount) external override {}
}
