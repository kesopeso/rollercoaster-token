// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/IPresale.sol";
import "./interfaces/IToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Presale is Ownable, IPresale {
    using SafeMath for uint256;

    uint256 public constant HARDCAP = 600 * 10**18;
    uint256 public constant MAX_CONTRIBUTION = 3 * 10**18;
    uint256 public constant LIQUIDITY_ALLOCATION_PERCENT = 60;

    uint256 public constant PRESALE_MAX_SUPPLY = 600 * 10**18; // if 600 eth collected, otherwise leftover burned
    uint256 public constant LIQUIDITY_MAX_SUPPLY = 162 * 10**18; // if 600 eth collected (360 eth for liquidity), otherwise leftover burned
    uint256 public constant RC_FARM_SUPPLY = 1000 * 10**18;
    uint256 public constant RC_ETH_FARM_SUPPLY = 1600 * 10**18;

    uint256 private immutable maxContributorsCount;
    uint256 private immutable contributorTokensPerCollectedEth;
    uint256 private immutable liquidityTokensPerCollectedEth;

    address private token;
    address private liquidityLock;
    address private uniswapRouter;
    address private rcFarm;
    address private rcEthFarm;
    uint256 private collected;
    bool private isPresaleActiveFlag;
    bool private isFcfsActiveFlag;
    bool private wasPresaleEndedFlag;
    mapping(address => bool) private contributors;
    mapping(address => uint256) private contributions;
    uint256 private contributorsCount;

    constructor() public {
        maxContributorsCount = HARDCAP.div(MAX_CONTRIBUTION);
        contributorTokensPerCollectedEth = PRESALE_MAX_SUPPLY.mul(10**18).div(HARDCAP);
        liquidityTokensPerCollectedEth = LIQUIDITY_MAX_SUPPLY.mul(10**18).div(HARDCAP);
    }

    modifier presaleActive() {
        require(isPresaleActiveFlag, "Presale is not active.");
        _;
    }

    modifier presaleNotActive() {
        require(!isPresaleActiveFlag, "Presale is active.");
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

    function tokenAddress() external view override returns (address) {
        return token;
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

    function addContributors(address[] memory _contributors) public override onlyOwner {
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
        address _token,
        address _liquidityLock,
        address _uniswapRouter,
        address _rcFarm,
        address _rcEthFarm,
        address[] memory _contributors
    ) external override onlyOwner presaleNotActive sufficientSupply(_token) {
        isPresaleActiveFlag = true;
        token = _token;
        liquidityLock = _liquidityLock;
        uniswapRouter = _uniswapRouter;
        rcFarm = _rcFarm;
        rcEthFarm = _rcEthFarm;
        addContributors(_contributors);
    }

    function activateFcfs() external override onlyOwner presaleActive {
        isFcfsActiveFlag = true;
    }

    function end(address payable _team) external override onlyOwner presaleActive {
        IToken rollerCoaster = IToken(token);

        // calculate liquidity share
        uint256 totalCollected = address(this).balance;
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
        uint256 teamEths = totalCollected.sub(liquidityEths);
        _team.transfer(teamEths);

        // transfer farm shares
        rollerCoaster.transfer(rcFarm, RC_FARM_SUPPLY);
        rollerCoaster.transfer(rcEthFarm, RC_ETH_FARM_SUPPLY);

        // burn the remaining balance and unlock token
        uint256 remainingBalance = rollerCoaster.balanceOf(address(this));
        rollerCoaster.burn(remainingBalance);
        rollerCoaster.unlock();

        // end presale
        isPresaleActiveFlag = false;
        wasPresaleEndedFlag = true;
    }

    receive() external payable presaleActive senderEligibleToContribute {
        uint256 totalContributionLeft = PRESALE_MAX_SUPPLY.sub(collected);
        uint256 senderContributionLeft = MAX_CONTRIBUTION.sub(contributions[msg.sender]);
        uint256 contributionLeft = Math.min(totalContributionLeft, senderContributionLeft);

        uint256 valueToAccept = Math.min(msg.value, contributionLeft);
        if (valueToAccept < msg.value) {
            uint256 valueToReturn = msg.value.sub(valueToAccept);
            _msgSender().transfer(valueToReturn);
        }

        if (valueToAccept == 0) {
            return;
        }

        collected = collected.add(valueToAccept);
        contributions[msg.sender] = contributions[msg.sender].add(valueToAccept);

        uint256 tokensToTransfer = contributorTokensPerCollectedEth.mul(valueToAccept).div(10**18);
        IERC20(token).transfer(msg.sender, tokensToTransfer);
    }
}
