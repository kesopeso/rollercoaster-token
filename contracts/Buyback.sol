// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./interfaces/IBuyback.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/GSN/Context.sol";

contract Buyback is Context, IBuyback {
    event BuybackInitialized(uint256 _totalAmount, uint256 _singleAmount);
    event SingleBuybackExecuted(address _sender, uint256 _senderRewardAmount, uint256 _buybackAmount);

    using SafeMath for uint256;

    address private token;
    address private uniswapRouter;
    address private treasury;
    address private weth;
    uint256 private totalBuyback;
    uint256 private singleBuyback;
    uint256 private alreadyBoughtBack;
    uint256 private lastBuybackTimestamp;
    uint256 private nextBuybackTimestamp;
    uint256 private lastBuybackBlockNumber;

    constructor(address _treasury, address _weth) public {
        treasury = _treasury;
        weth = _weth;
    }

    modifier scheduled() {
        require(block.timestamp >= nextBuybackTimestamp && nextBuybackTimestamp > 0, "Not scheduled yet.");
        _;
    }

    modifier available() {
        require(totalBuyback > alreadyBoughtBack, "No more funds available.");
        _;
    }

    function tokenAddress() external view override returns (address) {
        return token;
    }

    function uniswapRouterAddress() external view override returns (address) {
        return uniswapRouter;
    }

    function treasuryAddress() external view override returns (address) {
        return treasury;
    }

    function wethAddress() external view override returns (address) {
        return weth;
    }

    function totalAmount() external view override returns (uint256) {
        return totalBuyback;
    }

    function singleAmount() external view override returns (uint256) {
        return singleBuyback;
    }

    function boughtBackAmount() external view override returns (uint256) {
        return alreadyBoughtBack;
    }

    function lastBuyback() external view override returns (uint256) {
        return lastBuybackTimestamp;
    }

    function nextBuyback() external view override returns (uint256) {
        return nextBuybackTimestamp;
    }

    function lastBlockNumber() external view override returns (uint256) {
        return lastBuybackBlockNumber;
    }

    function init(address _token, address _uniswapRouter) external payable override {
        token = _token;
        uniswapRouter = _uniswapRouter;
        totalBuyback = msg.value;
        singleBuyback = totalBuyback.div(10);
        updateBuybackTimestamps();

        emit BuybackInitialized(totalBuyback, singleBuyback);
    }

    function buyback() external override scheduled available {
        uint256 fundsLeft = totalBuyback.sub(alreadyBoughtBack);
        uint256 actualBuyback = Math.min(fundsLeft, singleBuyback);

        // send 1% to the sender as a reward for triggering the function
        uint256 senderShare = actualBuyback.div(100);
        _msgSender().transfer(senderShare);

        // buy tokens with other 99% and send them to the treasury address
        uint256 buyShare = actualBuyback.sub(senderShare);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = token;
        IUniswapV2Router02(uniswapRouter).swapExactETHForTokens{ value: buyShare }(0, path, treasury, block.timestamp);

        alreadyBoughtBack = alreadyBoughtBack.add(actualBuyback);
        lastBuybackBlockNumber = block.number;
        updateBuybackTimestamps();

        emit SingleBuybackExecuted(msg.sender, senderShare, buyShare);
    }

    function updateBuybackTimestamps() private {
        lastBuybackTimestamp = nextBuybackTimestamp;
        nextBuybackTimestamp = (nextBuybackTimestamp > 0 ? nextBuybackTimestamp : block.timestamp) + 1 days;
    }
}
