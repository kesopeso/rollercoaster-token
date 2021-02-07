// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IFarmActivator.sol";

contract FarmActivatorMock is IFarmActivator {
    address private rewardToken;
    address private farmToken;

    function startFarmingShouldBeCalledWith(address _rewardToken, address _farmToken) external view {
        require(rewardToken == _rewardToken, "_rewardToken parameter missmatch.");
        require(farmToken == _farmToken, "_rewardToken parameter missmatch.");
    }

    function startFarming(address _rewardToken, address _farmToken) external override {
        rewardToken = _rewardToken;
        farmToken = _farmToken;
    }
}
