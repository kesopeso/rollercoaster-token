// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IPancakeswapRouter.sol";

contract PancakeswapRouterMock is IPancakeswapRouter {
    uint256 private _msgValue;
    address private _token;
    uint256 private _amountTokenDesired;
    uint256 private _amountTokenMin;
    uint256 private _amountETHMin;
    address private _to;

    uint256 private _sMsgValue;
    uint256 private _sAmountOutMin;
    address[] private _sPath;
    address private _sTo;
    uint256 private _sAmountOut;

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

    function swapExactETHForTokensShouldBeCalledWith(
        uint256 msgValue,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external view {
        require(msgValue == _sMsgValue, "msg.value parameter missmatch.");
        require(amountOutMin == _sAmountOutMin, "amountOutMin parameter missmatch.");
        require(path.length == _sPath.length, "path parameter length missmatch.");
        for (uint256 i; i < path.length; i++) {
            require(path[i] == _sPath[i], "path parameter elements missmatch.");
        }
        require(to == _sTo, "to parameter missmatch.");
    }

    function setSwapExactETHForTokensAmountOut(uint256 amountOut) external {
        _sAmountOut = amountOut;
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable override returns (uint256[] memory amounts) {
        _sMsgValue = msg.value;
        _sAmountOutMin = amountOutMin;
        _sPath = path;
        _sTo = to;

        // to silence warnings
        deadline = 0;
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = _sAmountOut;
    }
}
