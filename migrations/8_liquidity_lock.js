const Token = artifacts.require('Token');
const LiquidityLock = artifacts.require('LiquidityLock');
const { getTokenWethPairAddress } = require('../lib/pancakeswap');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping LiquidityLock contract migration.');
        return;
    }
    const token = await Token.deployed();
    const lpTokenAddress = getTokenWethPairAddress(token.address, network);
    const releaseTime = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 * 6; // 6 months lockup
    await deployer.deploy(LiquidityLock, lpTokenAddress, releaseTime);
};
