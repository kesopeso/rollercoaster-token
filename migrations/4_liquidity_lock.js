const Token = artifacts.require('TokenMock');
const LiquidityLock = artifacts.require('LiquidityLock');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping LiquidityLockyy contract migration.');
        return;
    }
    const token = await Token.deployed();
    const releaseTime = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 * 6; // 6 months lockup
    await deployer.deploy(LiquidityLock, token.address, releaseTime);
};
