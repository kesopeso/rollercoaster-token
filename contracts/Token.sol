// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/ITokenDistributor.sol";
import "./interfaces/ITransferLimiter.sol";
import "./interfaces/IToken.sol";

contract Token is ERC20Upgradeable, IToken {
    uint256 public constant BURN_PERCENT = 5;

    address private distributor;
    address private treasury;
    address private transferLimiter;
    address private uniswapPair;
    bool private isLocked;

    function initialize(
        string memory _name,
        string memory _symbol,
        address _distributor,
        address _treasury,
        address _transferLimiter
    ) public initializer {
        __Token_init(_name, _symbol, _distributor, _treasury, _transferLimiter);
    }

    function __Token_init(
        string memory _name,
        string memory _symbol,
        address _distributor,
        address _treasury,
        address _transferLimiter
    ) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(_name, _symbol);
        __Token_init_unchained(_distributor, _treasury, _transferLimiter);
    }

    function __Token_init_unchained(
        address _distributor,
        address _treasury,
        address _transferLimiter
    ) internal initializer {
        distributor = _distributor;
        treasury = _treasury;
        transferLimiter = _transferLimiter;
        isLocked = true;

        uint256 mintAmount = ITokenDistributor(distributor).getMaxSupply();
        _mint(distributor, mintAmount);
    }

    modifier tokensTransferable(address _from, address _to) {
        require(!isLocked || _from == distributor || _to == distributor, "Tokens are not transferable.");
        _;
    }

    modifier transferableAmount(address _to, uint256 _amount) {
        if (_to == uniswapPair) {
            uint256 transferLimitPerETH = ITransferLimiter(transferLimiter).getTransferLimitPerETH();
            if (transferLimitPerETH > 0) {
                uint256 transferLimit = transferLimitPerETH.div(2);
                require(_amount <= transferLimit, "Transfer amount is too big.");
            }
        }
        _;
    }

    modifier onlyDistributor() {
        require(msg.sender == distributor, "Only distributor allowed.");
        _;
    }

    modifier uniswapPairNotSet() {
        require(uniswapPair == address(0), "Uniswap pair is already set.");
        _;
    }

    function uniswapPairAddress() external view override returns (address) {
        return uniswapPair;
    }

    function setUniswapPair(address _uniswapPair) external override uniswapPairNotSet {
        uniswapPair = _uniswapPair;
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
    ) internal virtual override tokensTransferable(from, to) transferableAmount(to, amount) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        bool shouldBurnTokens =
            sender != distributor &&
                recipient != distributor &&
                sender != treasury &&
                recipient != treasury &&
                sender != uniswapPair;

        if (shouldBurnTokens) {
            uint256 burnAmount = amount.mul(BURN_PERCENT).div(100);
            _burn(sender, burnAmount);
            amount = amount.sub(burnAmount);
        }

        super._transfer(sender, recipient, amount);
    }

    uint256[45] private __gap;
}
