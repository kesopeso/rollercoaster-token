// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/IBuybackInitializer.sol";
import "./interfaces/IPresale.sol";
import "./interfaces/ITokenDistributor.sol";
import "./interfaces/IToken.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";

contract Presale is Ownable, IPresale, ITokenDistributor {
    event PresaleStarted();
    event FcfsActivated();
    event PresaleEnded();
    event ContributionAccepted(
        address indexed _contributor,
        uint256 _contribution,
        uint256 _receivedTokens,
        uint256 _contributions
    );
    event ContributionRefunded(address indexed _contributor, uint256 _contribution);

    using SafeMath for uint256;

    uint256 public constant BUYBACK_ALLOCATION_PERCENT = 50;
    uint256 public constant LIQUIDITY_ALLOCATION_PERCENT = 10;
    uint256 public constant PRESALE_MAX_SUPPLY = 600 * 10**18; // if 600 eth collected, otherwise leftover burned
    uint256 public constant LIQUIDITY_MAX_SUPPLY = 27 * 10**18; // if 600 eth collected (360 eth for liquidity), otherwise leftover burned
    uint256 public constant RC_FARM_SUPPLY = 1000 * 10**18;
    uint256 public constant RC_ETH_FARM_SUPPLY = 1600 * 10**18;

    uint256 private hardcap;
    uint256 private collected;
    uint256 private maxContribution;
    uint256 private maxContributorsCount;
    uint256 private contributorsCount;
    uint256 private contributorTokensPerCollectedEth;
    uint256 private liquidityTokensPerCollectedEth;
    address private token;
    address private buyback;
    address private liquidityLock;
    address private uniswapRouter;
    address private rcFarm;
    address private rcEthFarm;
    bool private isPresaleActiveFlag;
    bool private isFcfsActiveFlag;
    bool private wasPresaleEndedFlag;
    mapping(address => bool) private contributors;
    mapping(address => uint256) private contributions;

    modifier presaleActive() {
        require(isPresaleActiveFlag, "Presale is not active.");
        _;
    }

    modifier presaleNotActive() {
        require(!isPresaleActiveFlag, "Presale is active.");
        _;
    }

    modifier presaleNotEnded() {
        require(!wasPresaleEndedFlag, "Presale was ended.");
        _;
    }

    modifier sufficientSupply(address _token) {
        uint256 supply = IERC20(_token).balanceOf(address(this));
        uint256 minSupply = PRESALE_MAX_SUPPLY.add(LIQUIDITY_MAX_SUPPLY).add(RC_FARM_SUPPLY).add(RC_ETH_FARM_SUPPLY);
        require(supply >= minSupply, "Insufficient supply.");
        _;
    }

    modifier senderEligibleToContribute() {
        require(isFcfsActiveFlag || contributors[msg.sender], "Not eligible to participate.");
        _;
    }

    function getMaxSupply() external view override returns (uint256) {
        return PRESALE_MAX_SUPPLY.add(LIQUIDITY_MAX_SUPPLY).add(RC_FARM_SUPPLY).add(RC_ETH_FARM_SUPPLY);
    }

    function tokenAddress() external view override returns (address) {
        return token;
    }

    function buybackAddress() external view override returns (address) {
        return buyback;
    }

    function liquidityLockAddress() external view override returns (address) {
        return liquidityLock;
    }

    function uniswapRouterAddress() external view override returns (address) {
        return uniswapRouter;
    }

    function rcFarmAddress() external view override returns (address) {
        return rcFarm;
    }

    function rcEthFarmAddress() external view override returns (address) {
        return rcEthFarm;
    }

    function collectedAmount() external view override returns (uint256) {
        return collected;
    }

    function hardcapAmount() external view override returns (uint256) {
        return hardcap;
    }

    function maxContributionAmount() external view override returns (uint256) {
        return maxContribution;
    }

    function isPresaleActive() external view override returns (bool) {
        return isPresaleActiveFlag;
    }

    function isFcfsActive() external view override returns (bool) {
        return isFcfsActiveFlag;
    }

    function wasPresaleEnded() external view override returns (bool) {
        return wasPresaleEndedFlag;
    }

    function isWhitelisted(address _contributor) external view override returns (bool) {
        return contributors[_contributor];
    }

    function contribution(address _contributor) external view override returns (uint256) {
        return contributions[_contributor];
    }

    function addContributors(address[] memory _contributors) public override onlyOwner presaleActive {
        for (uint256 i; i < _contributors.length; i++) {
            bool isAlreadyAdded = contributors[_contributors[i]];
            if (isAlreadyAdded) {
                continue;
            }
            require(contributorsCount < maxContributorsCount, "Max contributors reached.");
            contributorsCount++;
            contributors[_contributors[i]] = true;
        }
    }

    function start(
        uint256 _hardcap,
        uint256 _maxContribution,
        address _token,
        address _buyback,
        address _liquidityLock,
        address _uniswapRouter,
        address _rcFarm,
        address _rcEthFarm,
        address[] calldata _contributors
    ) external override onlyOwner presaleNotActive presaleNotEnded sufficientSupply(_token) {
        isPresaleActiveFlag = true;
        hardcap = _hardcap;
        maxContribution = _maxContribution;
        maxContributorsCount = hardcap.div(maxContribution);
        contributorTokensPerCollectedEth = PRESALE_MAX_SUPPLY.mul(10**18).div(hardcap);
        liquidityTokensPerCollectedEth = LIQUIDITY_MAX_SUPPLY.mul(10**18).div(hardcap);
        token = _token;
        buyback = _buyback;
        liquidityLock = _liquidityLock;
        uniswapRouter = _uniswapRouter;
        rcFarm = _rcFarm;
        rcEthFarm = _rcEthFarm;
        addContributors(_contributors);
        emit PresaleStarted();
    }

    function activateFcfs() external override onlyOwner presaleActive {
        if (isFcfsActiveFlag) {
            return;
        }
        isFcfsActiveFlag = true;
        emit FcfsActivated();
    }

    function end(address payable _team) external override onlyOwner presaleActive {
        IERC20 rollerCoaster = IERC20(token);
        uint256 totalCollected = address(this).balance;

        // calculate buyback and execute it
        uint256 buybackEths = totalCollected.mul(BUYBACK_ALLOCATION_PERCENT).div(100);
        IBuybackInitializer(buyback).init{ value: buybackEths }(token, uniswapRouter);

        // calculate liquidity share
        uint256 liquidityEths = totalCollected.mul(LIQUIDITY_ALLOCATION_PERCENT).div(100);
        uint256 liquidityTokens = liquidityTokensPerCollectedEth.mul(totalCollected).div(10**18);

        // approve router and add liquidity
        rollerCoaster.approve(uniswapRouter, liquidityTokens);
        IUniswapV2Router02(uniswapRouter).addLiquidityETH{ value: liquidityEths }(
            token,
            liquidityTokens,
            liquidityTokens,
            liquidityEths,
            liquidityLock,
            block.timestamp
        );

        // transfer team share
        uint256 teamEths = totalCollected.sub(liquidityEths).sub(buybackEths);
        _team.transfer(teamEths);

        // transfer farm shares
        rollerCoaster.transfer(rcFarm, RC_FARM_SUPPLY);
        rollerCoaster.transfer(rcEthFarm, RC_ETH_FARM_SUPPLY);

        // burn the remaining balance and unlock token
        IToken(token).burnDistributorTokensAndUnlock();

        // end presale
        isPresaleActiveFlag = false;
        wasPresaleEndedFlag = true;
        emit PresaleEnded();
    }

    receive() external payable presaleActive senderEligibleToContribute {
        uint256 totalContributionLeft = PRESALE_MAX_SUPPLY.sub(collected);
        uint256 senderContributionLeft = maxContribution.sub(contributions[msg.sender]);
        uint256 contributionLeft = Math.min(totalContributionLeft, senderContributionLeft);

        uint256 valueToAccept = Math.min(msg.value, contributionLeft);
        if (valueToAccept > 0) {
            collected = collected.add(valueToAccept);
            contributions[msg.sender] = contributions[msg.sender].add(valueToAccept);

            uint256 tokensToTransfer = contributorTokensPerCollectedEth.mul(valueToAccept).div(10**18);
            IERC20(token).transfer(msg.sender, tokensToTransfer);

            emit ContributionAccepted(msg.sender, valueToAccept, tokensToTransfer, collected);
        }

        uint256 valueToRefund = msg.value.sub(valueToAccept);
        if (valueToRefund > 0) {
            _msgSender().transfer(valueToRefund);

            emit ContributionRefunded(msg.sender, valueToRefund);
        }
    }
}
