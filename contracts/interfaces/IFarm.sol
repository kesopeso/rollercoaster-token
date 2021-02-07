// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IFarm {
    function totalRewardSupply() external view returns (uint256);

    function rewardTokenAddress() external view returns (address);

    function farmTokenAddress() external view returns (address);

    function stake(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function harvest() external;

    function claim() external;
}
