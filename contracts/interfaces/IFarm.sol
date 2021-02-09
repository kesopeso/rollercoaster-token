// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IFarm {
    event HarvestCreated(address indexed _staker, uint256 _idx, uint256 _timestamp, uint256 _amount);

    event RewardClaimed(address indexed _staker, uint256 indexed _harvestChunkIdx, uint256 _timestamp, uint256 _amount);

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
