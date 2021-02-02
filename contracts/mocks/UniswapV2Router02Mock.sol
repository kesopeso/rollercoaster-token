// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IUniswapV2Router02.sol";

contract UniswapV2Router02Mock is IUniswapV2Router02 {
    uint256 private _msgValue;
    address private _token;
    uint256 private _amountTokenDesired;
    uint256 private _amountTokenMin;
    uint256 private _amountETHMin;
    address private _to;

    function addLiquidityETHShouldBeCalledWith(
        uint256 msgValue,
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to
    ) external view {
        require(msgValue == _msgValue, "msg.value parameter missmatch.");
        require(token == _token, "token parameter missmatch.");
        require(amountTokenDesired == _amountTokenDesired, "amountTokenDesired parameter missmatch.");
        require(amountTokenMin == _amountTokenMin, "amountTokenMin parameter missmatch.");
        require(amountETHMin == _amountETHMin, "amountETHMin parameter missmatch.");
        require(to == _to, "to parameter missmatch.");
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        _msgValue = msg.value;
        _token = token;
        _amountTokenDesired = amountTokenDesired;
        _amountTokenMin = amountTokenMin;
        _amountETHMin = amountETHMin;
        _to = to;

        // to silence the warnings
        deadline = 0;
        amountToken = 0;
        amountETH = 0;
        liquidity = 0;
    }
}
