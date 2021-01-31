// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    function unlock() external;

    function isUnlocked() external returns (bool);

    function burn(uint256 _amount) external;
}
