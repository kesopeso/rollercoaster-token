const Presale = artifacts.require('Presale');
const LiquidityLock = artifacts.require('LiquidityLock');
const UniswapV2Router02Mock = artifacts.require('UniswapV2Router02Mock');
const TokenMock = artifacts.require('TokenMock');
const { expect } = require('chai');
const { BN, send, expectRevert, ether, constants } = require('@openzeppelin/test-helpers');

contract('Presale', (accounts) => {
    let presale;
    let token;
    let liquidityLock;
    let uniswapRouter;
    const [alice, bob, curtis, dick, earl] = accounts;

    beforeEach(async () => {
        presale = await Presale.new();
        token = await TokenMock.new(presale.address, ether('3362'));
        const liquidityUnlockTimestamp = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 * 6;
        liquidityLock = await LiquidityLock.new(token.address, liquidityUnlockTimestamp);
        uniswapRouter = await UniswapV2Router02Mock.new();
    });

    context('before starting', () => {
        const presaleStart = (contributors, from) =>
            presale.start(
                ether('9'),
                ether('3'),
                token.address,
                liquidityLock.address,
                uniswapRouter.address,
                constants.ZERO_ADDRESS,
                constants.ZERO_ADDRESS,
                contributors,
                { from }
            );

        const presaleActivateFcfs = (from) => presale.activateFcfs({ from });

        const presaleEnd = (from) => presale.end(constants.ZERO_ADDRESS, { from });

        const presaleAddContributors = (contributors, from) => presale.addContributors(contributors, { from });

        it('should not allow start from non owner', async () => {
            await expectRevert(presaleStart([], bob), 'Ownable: caller is not the owner');
        });

        it('should not allow activate fcfs from non owner', async () => {
            await expectRevert(presaleActivateFcfs(bob), 'Ownable: caller is not the owner');
        });

        it('should not allow end from non owner', async () => {
            await expectRevert(presaleEnd(bob), 'Ownable: caller is not the owner');
        });

        it('should not allow adding contributors from non owner', async () => {
            await expectRevert(presaleAddContributors([], bob), 'Ownable: caller is not the owner');
        });

        it('should now allow activate fcfs if not started yet', async () => {
            await expectRevert(presaleActivateFcfs(alice), 'Presale is not active.');
        });

        it('should now allow end if not started yet', async () => {
            await expectRevert(presaleEnd(alice), 'Presale is not active.');
        });

        it('should now allow adding contributors if not started yet', async () => {
            await expectRevert(presaleAddContributors([], alice), 'Presale is not active.');
        });

        it('should not allow start if insufficient token supply', async () => {
            token = await TokenMock.new(presale.address, ether('3361'));
            await expectRevert(presaleStart([], alice), 'Insufficient supply.');
        });

        it('should not allow investments', async () => {
            await expectRevert(send.ether(bob, presale.address, ether('3')), 'Presale is not active.');
        });

        it('should not allowed setting more contributors than allowed', async () => {
            await expectRevert(presaleStart([bob, curtis, dick, earl], alice), 'Max contributors reached.');
        });

        it('should set variables correctly on start', async () => {
            await presaleStart([bob, curtis, dick], alice);
            expect(await presale.tokenAddress()).to.equal(token.address);
            expect(await presale.liquidityLockAddress()).to.equal(liquidityLock.address);
            expect(await presale.uniswapRouterAddress()).to.equal(uniswapRouter.address);
            expect(await presale.rcFarmAddress()).to.equal(constants.ZERO_ADDRESS);
            expect(await presale.rcEthFarmAddress()).to.equal(constants.ZERO_ADDRESS);
            expect((await presale.collectedAmount()).eq(ether('0'))).to.be.true;
            expect((await presale.hardcapAmount()).eq(ether('9'))).to.be.true;
            expect((await presale.maxContributionAmount()).eq(ether('3'))).to.be.true;
            expect(await presale.isPresaleActive()).to.be.true;
            expect(await presale.isFcfsActive()).to.be.false;
            expect(await presale.wasPresaleEnded()).to.be.false;
            expect(await presale.isWhitelisted(bob)).to.be.true;
            expect(await presale.isWhitelisted(curtis)).to.be.true;
            expect(await presale.isWhitelisted(dick)).to.be.true;
            expect(await presale.isWhitelisted(earl)).to.be.false;
            expect((await presale.contribution(bob)).eq(ether('0'))).to.be.true;
            expect((await presale.contribution(curtis)).eq(ether('0'))).to.be.true;
            expect((await presale.contribution(dick)).eq(ether('0'))).to.be.true;
            expect((await presale.contribution(earl)).eq(ether('0'))).to.be.true;
        });
    });

    context('after start', () => {});

    context('after allowing contributions from all', () => {});

    context('after stoping', () => {});
});
