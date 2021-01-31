const LiquidityLock = artifacts.require('LiquidityLock');

module.exports = (deployer) => {
    const tokenAddress = '';
    const releaseTime = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 * 6; // 6 months lockup
    deployer.deploy(LiquidityLock, tokenAddress, releaseTime);
};
