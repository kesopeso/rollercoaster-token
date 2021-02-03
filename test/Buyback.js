const Treasury = artifacts.require('Treasury');
const Buyback = artifacts.require('Buyback');
const UniswapV2Router02Mock = artifacts.require('UniswapV2Router02Mock');
const TokenMock = artifacts.require('TokenMock');
const { expect } = require('chai');
const { BN, balance, expectRevert, ether, constants, time } = require('@openzeppelin/test-helpers');

contract('Buyback', (accounts) => {
    let buyback;
    let treasury;
    let uniswapRouter;
    let token;
    const [alice, bob] = accounts;

    beforeEach(async () => {
        treasury = await Treasury.new();
        buyback = await Buyback.new(alice, treasury.address, constants.ZERO_ADDRESS);
        uniswapRouter = await UniswapV2Router02Mock.new();
        token = await TokenMock.new(alice, ether('1000'));
    });

    const buybackInit = (from, amount) =>
        buyback.init(token.address, uniswapRouter.address, { from, value: ether(amount.toString()) });

    const buybackBuyback = (from) => buyback.buyback({ from });

    context('before init', () => {
        it('should not allow init from non intializer', async () => {
            await expectRevert(buybackInit(bob, 10), 'Only initializer allowed.');
        });

        it('should not allow buyback triggering from anybody', async () => {
            await expectRevert(buyback.buyback({ from: alice }), 'Not initialized.');
            await expectRevert(buyback.buyback({ from: bob }), 'Not initialized.');
        });

        it('should init successfully', async () => {
            const buybackTracker = await balance.tracker(buyback.address);
            await buybackInit(alice, 10);

            const buybackDelta = await buybackTracker.delta();
            expect(buybackDelta.eq(ether('10'))).to.be.true;

            expect(await buyback.tokenAddress()).to.equal(token.address);
            expect(await buyback.initializerAddress()).to.equal(alice);
            expect(await buyback.uniswapRouterAddress()).to.equal(uniswapRouter.address);
            expect(await buyback.treasuryAddress()).to.equal(treasury.address);
            expect(await buyback.wethAddress()).to.equal(constants.ZERO_ADDRESS);
            expect((await buyback.totalAmount()).eq(ether('10'))).to.be.true;
            expect((await buyback.singleAmount()).eq(ether('1'))).to.be.true;
            expect((await buyback.boughtBackAmount()).eq(ether('0'))).to.be.true;
            expect((await buyback.lastBuyback()).isZero()).to.be.true;
            expect((await buyback.nextBuyback()).eq((await time.latest()).add(time.duration.days(1)))).to.be.true;
            expect((await buyback.lastBuybackBlock()).isZero()).to.be.true;
        });
    });

    context('after init', () => {
        beforeEach(async () => {
            await buybackInit(alice, 10);
        });

        it('should not allow unscheduled buyback from anybody', async () => {
            await expectRevert(buybackBuyback(alice), 'Not scheduled yet.');
            await expectRevert(buybackBuyback(bob), 'Not scheduled yet.');
        });

        it('should execute buyback successfully if scheduled', async () => {
            await expectRevert(buybackBuyback(bob), 'Not scheduled yet.');
            await time.increase(time.duration.days(1));

            const bobTracker = await balance.tracker(bob);
            const { receipt } = await buybackBuyback(bob);

            // we must take into consideration that default gas price on ganache is 20gwei
            const txFee = ether('0.00000002').mul(new BN(receipt.gasUsed));
            const rewardAmount = (await bobTracker.delta()).add(txFee);
            expect(rewardAmount.eq(ether('0.01'))).to.be.true;

            await uniswapRouter.swapExactETHForTokensShouldBeCalledWith(
                ether('0.99'),
                ether('0'),
                [constants.ZERO_ADDRESS, token.address],
                treasury.address
            );

            expect((await buyback.boughtBackAmount()).eq(ether('1'))).to.be.true;

            const lastExecution = await time.latest();
            expect((await buyback.lastBuyback()).eq(lastExecution)).to.be.true;

            const nextExecution = lastExecution.add(time.duration.days(1));
            expect((await buyback.nextBuyback()).eq(nextExecution)).to.be.true;

            const blockNumber = await time.latestBlock();
            expect((await buyback.lastBuybackBlock()).eq(blockNumber)).to.be.true;
        });
    });
});
