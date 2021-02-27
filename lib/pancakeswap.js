const { constants } = require('@openzeppelin/test-helpers');
const { Token, ChainId, WETH, Pair } = require('@pancakeswap-libs/sdk');

const getWethAddress = (network) => {
    switch (network) {
        case 'bscmainnet':
            return WETH[ChainId.MAINNET].address;
        case 'bsctestnet':
            return WETH[ChainId.BSCTESTNET].address;
        default:
            return constants.ZERO_ADDRESS;
    }
};

const getTokenWethPairAddress = (tokenAddress, network) => {
    let chainId;
    switch (network) {
        case 'bscmainnet':
            chainId = ChainId.MAINNET;
            break;
        case 'bsctestnet':
            chainId = ChainId.BSCTESTNET;
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
