// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/ITokenDistributor.sol";
import "../interfaces/IToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenDistributorMock is ITokenDistributor {
    uint256 private maxSupply;

    constructor(uint256 _maxSupply) public {
        maxSupply = _maxSupply;
    }

    function getMaxSupply() external view override returns (uint256) {
        return maxSupply;
    }

    function transfer(
        address _token,
        address _to,
        uint256 _amount
    ) external {
        IERC20(_token).transfer(_to, _amount);
    }

    function burnDistributorTokensAndUnlock(address _token) external {
        IToken(_token).burnDistributorTokensAndUnlock();
    }
}
