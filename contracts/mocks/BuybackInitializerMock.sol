// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IBuybackInitializer.sol";

contract BuybackInitializerMock is IBuybackInitializer {
    uint256 private msgValue;
    address private token;
    address private pancakeswapRouter;
    uint256 private minTokensToHold;

    function initShouldBeCalledWith(
        uint256 _msgValue,
        address _token,
        address _pancakeswapRouter,
        uint256 _minTokensToHold
    ) external view {
        require(msgValue == _msgValue, "msg.value parameter missmatch.");
        require(token == _token, "_token parameter missmatch.");
        require(pancakeswapRouter == _pancakeswapRouter, "_pancakeswapRouter parameter missmatch.");
        require(minTokensToHold == _minTokensToHold, "_minTokensToHold parameter missmatch.");
    }

    function init(
        address _token,
        address _pancakeswapRouter,
        uint256 _minTokensToHold
    ) external payable override {
        msgValue = msg.value;
        token = _token;
        pancakeswapRouter = _pancakeswapRouter;
        minTokensToHold = _minTokensToHold;
    }
}
