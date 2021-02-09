// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IFarm {
    event SnapshotAdded(uint256 _id, uint256 _intervalId, uint256 _timestamp, uint256 _totalAmount);

    event HarvestCreated(address indexed _staker, uint256 _id, uint256 _timestamp, uint256 _amount);

    event RewardClaimed(address indexed _staker, uint256 indexed _harvestId, uint256 _timestamp, uint256 _amount);

    function farmingActive() external view returns (bool);

    function totalRewardSupply() external view returns (uint256);

    function intervalReward() external view returns (uint256);

    function nextIntervalTimestamp() external view returns (uint256);

    function rewardTokenAddress() external view returns (address);

    function farmTokenAddress() external view returns (address);

    function singleStaked(address _staker) external view returns (uint256);

    function totalStaked() external view returns (uint256);

    function stake(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function harvest() external;

    function claim() external;

    function harvestable(address _staker) external view returns (uint256);

    function claimable(address _staker) external view returns (uint256);

    function harvested(address _staker) external view returns (uint256);
}
