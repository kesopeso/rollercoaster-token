// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/ITransferLimiter.sol";

contract TransferLimiterMock is ITransferLimiter {
    uint256 private transferLimit;

    function setTransferLimitPerETH(uint256 _transferLimit) external {
        transferLimit = _transferLimit;
    }

    function getTransferLimitPerETH() external view override returns (uint256) {
        return transferLimit;
    }
}
