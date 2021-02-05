const { constants } = require('@openzeppelin/test-helpers');
const { Token, ChainId, WETH, Pair } = require('@uniswap/sdk');

const getWethAddress = (network) => {
    switch (network) {
        case 'mainnet':
            return WETH[ChainId.MAINNET].address;
        case 'rinkeby':
            return WETH[ChainId.RINKEBY].address;
        case 'kovan':
            return WETH[ChainId.KOVAN].address;
        default:
            return constants.ZERO_ADDRESS;
    }
};

const getTokenWethPairAddress = (tokenAddress, network) => {
    let chainId;
    switch (network) {
        case 'mainnet':
            chainId = ChainId.MAINNET;
            break;
        case 'rinkeby':
            chainId = ChainId.RINKEBY;
            break;
        case 'kovan':
            chainId = ChainId.KOVAN;
            break;
        default:
            return constants.ZERO_ADDRESS;
    }

    const token = new Token(chainId, tokenAddress, 18);
    const weth = WETH[chainId];
    return Pair.getAddress(token, weth);
};

module.exports = {
    getWethAddress,
    getTokenWethPairAddress,
};
