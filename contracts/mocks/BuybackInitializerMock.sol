// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IBuybackInitializer.sol";

contract BuybackInitializerMock is IBuybackInitializer {
    uint256 private msgValue;
    address private token;
    address private uniswapRouter;

    function initShouldBeCalledWith(
        uint256 _msgValue,
        address _token,
        address _uniswapRouter
    ) external view {
        require(msgValue == _msgValue, "msg.value parameter missmatch.");
        require(token == _token, "_token parameter missmatch.");
        require(uniswapRouter == _uniswapRouter, "_uniswapRouter parameter missmatch.");
    }

    function init(address _token, address _uniswapRouter) external payable override {
        msgValue = msg.value;
        token = _token;
        uniswapRouter = _uniswapRouter;
    }
}
