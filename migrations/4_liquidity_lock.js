const Token = artifacts.require('TokenMock');
const LiquidityLock = artifacts.require('LiquidityLock');

module.exports = async (deployer) => {
    const token = await Token.deployed();
    const releaseTime = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 * 6; // 6 months lockup
    await deployer.deploy(LiquidityLock, token.address, releaseTime);
};
