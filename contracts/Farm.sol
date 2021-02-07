// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./interfaces/IFarm.sol";
import "./interfaces/IFarmActivator.sol";

contract Farm is Initializable, IFarm, IFarmActivator {
    uint256 private totalReward;
    address private activator;
    IERC20 private rewardToken;
    IERC20 private farmToken;
    bool private isFarmingStarted;

    struct Snapshots {
        uint256[] timestamp;
        uint256[] amount;
    }

    struct Harvests {
        uint256[] timestamp;
        uint256[] claimed;
        uint256[] amount;
    }

    mapping(address => Harvests) private harvestHistory;

    function initialize(address _activator) external initializer {
        __Farm_init(_activator);
    }

    function __Farm_init(address _activator) internal initializer {
        __Farm_init_unchained(_activator);
    }

    function __Farm_init_unchained(address _activator) internal initializer {
        activator = _activator;
        isFarmingStarted = false;
    }

    modifier onlyActivator() {
        require(msg.sender == activator, "Only activator allowed.");
        _;
    }

    modifier farmingNotStarted() {
        require(!isFarmingStarted, "Farming was already started.");
        _;
    }

    modifier farmingStarted() {
        require(isFarmingStarted, "Farming not started yet.");
        _;
    }

    modifier rewardTokensDeposited(address _rewardToken) {
        uint256 balance = IERC20(_rewardToken).balanceOf(address(this));
        require(balance > 0, "Reward tokens are not deposited.");
        _;
    }

    function totalRewardSupply() external view override returns (uint256) {
        return totalReward;
    }

    function rewardTokenAddress() external view override returns (address) {
        return address(rewardToken);
    }

    function farmTokenAddress() external view override returns (address) {
        return address(farmToken);
    }

    function startFarming(address _rewardToken, address _farmToken)
        external
        override
        onlyActivator
        farmingNotStarted
        rewardTokensDeposited(_rewardToken)
    {
        rewardToken = IERC20(_rewardToken);
        farmToken = IERC20(_farmToken);
        totalReward = rewardToken.balanceOf(address(this));
        isFarmingStarted = true;
    }

    function stake(uint256 _amount) external override {
        // transfer tokens
        // update snapshots
    }

    function withdraw(uint256 _amount) external override {
        // transfer tokens
        // update snapshots
    }

    function harvest() external override {
        // check last harvest
    }

    function claim() external override {
        // check claimable and claim
    }

    uint256[43] private __gap;
}
