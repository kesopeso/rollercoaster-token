// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IBuybackInitializer {
    function init(address _token, address _uniswapRouter) external payable;
}
