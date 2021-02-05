// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/ITokenDistributor.sol";
import "./interfaces/IToken.sol";

contract Token is ERC20Upgradeable, IToken {
    address private distributor;
    bool private isLocked;

    function initialize(
        string memory _name,
        string memory _symbol,
        address _distributor
    ) public initializer {
        __Token_init(_name, _symbol, _distributor);
    }

    function __Token_init(
        string memory _name,
        string memory _symbol,
        address _distributor
    ) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(_name, _symbol);
        __Token_init_unchained(_distributor);
    }

    function __Token_init_unchained(address _distributor) internal initializer {
        distributor = _distributor;
        isLocked = true;

        uint256 mintAmount = ITokenDistributor(distributor).getMaxSupply();
        _mint(distributor, mintAmount);
    }

    modifier distributorTokensOrUnlocked(address _from, address _to) {
        require(!isLocked || _from == distributor || _to == distributor, "Tokens are locked.");
        _;
    }

    modifier onlyDistributor() {
        require(msg.sender == distributor, "Only distributor allowed.");
        _;
    }

    function burnDistributorTokensAndUnlock() external override onlyDistributor {
        uint256 burnAmount = balanceOf(distributor);
        _burn(distributor, burnAmount);
        isLocked = false;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override distributorTokensOrUnlocked(from, to) {
        super._beforeTokenTransfer(from, to, amount);
    }

    uint256[48] private __gap;
}
