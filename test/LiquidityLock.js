const TokenMock = artifacts.require('TokenMock');
const LiquidityLock = artifacts.require('LiquidityLock');
const { expect } = require('chai');
const { expectRevert, ether, time } = require('@openzeppelin/test-helpers');

contract('LiquidityLock', (accounts) => {
    it('locks tokens for certain amount of time and allows beneficiary to withdraw later on', async () => {
        const [alice, bob] = accounts;
        const tokensAmount = ether('5');
        const token = await TokenMock.new(alice, tokensAmount);
        
        const release = (await time.latest()).add(time.duration.years(1));
        const liquidityLock = await LiquidityLock.new(token.address, release, { from: bob });
        await token.transfer(liquidityLock.address, tokensAmount);

        await expectRevert(liquidityLock.release(), 'TokenTimelock: current time is before release time');

        await time.increase(time.duration.days(200));
        await expectRevert(liquidityLock.release(), 'TokenTimelock: current time is before release time');

        await time.increase(time.duration.days(200));
        await liquidityLock.release();

        const liquidityLockBalance = await token.balanceOf(liquidityLock.address);
        expect(liquidityLockBalance.isZero()).to.be.true;

        const bobBalance = await token.balanceOf(bob);
        expect(bobBalance.eq(tokensAmount)).to.be.true;
    });
});
