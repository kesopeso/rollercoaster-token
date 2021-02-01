const Presale = artifacts.require('Presale');
const LiquidityLock = artifacts.require('LiquidityLock');
const UniswapV2Router02Mock = artifacts.require('UniswapV2Router02Mock');
const TokenMock = artifacts.require('TokenMock');
const { expect } = require('chai');
const { send, balance, expectRevert, ether, constants } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

contract('Presale', (accounts) => {
    let presale;
    let token;
    let liquidityLock;
    let uniswapRouter;
    const [alice, bob, curtis, dick, earl, frank, greg] = accounts;

    const sendEther = (from, value) =>
        web3.eth.sendTransaction({ from, to: presale.address, value, gas: 150000, gasPrice: 0 });

    const presaleStart = (contributors, from) =>
        presale.start(
            ether('6'),
            ether('3'),
            token.address,
            liquidityLock.address,
            uniswapRouter.address,
            frank,
            greg,
            contributors,
            { from }
        );

    const presaleActivateFcfs = (from) => presale.activateFcfs({ from });

    const presaleEnd = (from, to) => presale.end(to, { from });

    const presaleAddContributors = (contributors, from) => presale.addContributors(contributors, { from });

    beforeEach(async () => {
        presale = await Presale.new();
        token = await TokenMock.new(presale.address, ether('3362'));
        const liquidityUnlockTimestamp = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 * 6;
        liquidityLock = await LiquidityLock.new(token.address, liquidityUnlockTimestamp);
        uniswapRouter = await UniswapV2Router02Mock.new();
    });

    context('non owners', async () => {
        it('should not allow start from non owner', async () => {
            await expectRevert(presaleStart([], bob), 'Ownable: caller is not the owner');
        });

        it('should not allow activate fcfs from non owner', async () => {
            await expectRevert(presaleActivateFcfs(bob), 'Ownable: caller is not the owner');
        });

        it('should not allow end from non owner', async () => {
            await expectRevert(presaleEnd(bob, dick), 'Ownable: caller is not the owner');
        });

        it('should not allow adding contributors from non owner', async () => {
            await expectRevert(presaleAddContributors([], bob), 'Ownable: caller is not the owner');
        });
    });

    context('before starting', () => {
        it('should now allow activate fcfs if not started yet', async () => {
            await expectRevert(presaleActivateFcfs(alice), 'Presale is not active.');
        });

        it('should now allow end if not started yet', async () => {
            await expectRevert(presaleEnd(alice, dick), 'Presale is not active.');
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
            await expectRevert(presaleStart([bob, curtis, dick], alice), 'Max contributors reached.');
        });

        it('should set variables correctly on start', async () => {
            await presaleStart([bob, curtis], alice);
            expect(await presale.tokenAddress()).to.equal(token.address);
            expect(await presale.liquidityLockAddress()).to.equal(liquidityLock.address);
            expect(await presale.uniswapRouterAddress()).to.equal(uniswapRouter.address);
            expect(await presale.rcFarmAddress()).to.equal(frank);
            expect(await presale.rcEthFarmAddress()).to.equal(greg);
            expect((await presale.collectedAmount()).eq(ether('0'))).to.be.true;
            expect((await presale.hardcapAmount()).eq(ether('6'))).to.be.true;
            expect((await presale.maxContributionAmount()).eq(ether('3'))).to.be.true;
            expect(await presale.isPresaleActive()).to.be.true;
            expect(await presale.isFcfsActive()).to.be.false;
            expect(await presale.wasPresaleEnded()).to.be.false;
            expect(await presale.isWhitelisted(bob)).to.be.true;
            expect(await presale.isWhitelisted(curtis)).to.be.true;
            expect(await presale.isWhitelisted(dick)).to.be.false;
            expect((await presale.contribution(bob)).eq(ether('0'))).to.be.true;
            expect((await presale.contribution(curtis)).eq(ether('0'))).to.be.true;
            expect((await presale.contribution(dick)).eq(ether('0'))).to.be.true;
        });
    });

    context('after start', () => {
        beforeEach(async () => {
            await presaleStart([bob, curtis], alice);
        });

        it('should not allow double start', async () => {
            await expectRevert(presaleStart([], alice), 'Presale is active.');
        });

        it('should not allow investment from non whitelisted address', async () => {
            await expectRevert(send.ether(dick, presale.address, ether('3')), 'Not eligible to participate.');
        });

        it('should allow investment from whitelisted address', async () => {
            await sendEther(bob, ether('3'));
            const balance = await token.balanceOf(bob);
            expect(balance.eq(ether('300'))).to.be.true;
        });

        it('should allow multiple investments from whitelisted address', async () => {
            await sendEther(bob, ether('1'));
            await sendEther(bob, ether('1'));
            const balance = await token.balanceOf(bob);
            expect(balance.eq(ether('200'))).to.be.true;
        });

        it('should allow multiple investments up to max from whitelisted address', async () => {
            await sendEther(bob, ether('1'));
            await sendEther(bob, ether('1'));
            await sendEther(bob, ether('1'));
            const balance = await token.balanceOf(bob);
            expect(balance.eq(ether('300'))).to.be.true;
        });

        it('should allow multiple investments over max and return the excess from whitelisted address', async () => {
            const tracker = await balance.tracker(bob);
            await sendEther(bob, ether('1'));
            let bobContribution = await presale.contribution(bob);
            expect(bobContribution.eq(ether('1'))).to.be.true;

            await sendEther(bob, ether('1'));
            bobContribution = await presale.contribution(bob);
            expect(bobContribution.eq(ether('2'))).to.be.true;

            await sendEther(bob, ether('2'));
            bobContribution = await presale.contribution(bob);
            expect(bobContribution.eq(ether('3'))).to.be.true;

            const delta = await tracker.delta();
            expect(delta.eq(ether('-3'))).to.be.true;

            const bobTokenBalance = await token.balanceOf(bob);
            expect(bobTokenBalance.eq(ether('300'))).to.be.true;
        });

        it('should start fcfs correctly', async () => {
            await presaleActivateFcfs(alice);
            expect(await presale.isFcfsActive()).to.be.true;
        });
    });

    context('after allowing contributions from all', () => {
        it('should allow investment from non whitelisted addresses if fcfs active', async () => {
            await presaleStart([bob, curtis], alice);
            await expectRevert(send.ether(dick, presale.address, ether('2')), 'Not eligible to participate.');
            await presaleActivateFcfs(alice);

            const tracker = await balance.tracker(dick);
            await sendEther(dick, ether('2'));
            const delta = await tracker.delta();
            expect(delta.eq(ether('-2'))).to.be.true;

            const dickTokenBalance = await token.balanceOf(dick);
            expect(dickTokenBalance.eq(ether('200'))).to.be.true;
        });

        it('should end presale successfully', async () => {
            await presaleStart([bob, curtis], alice);
            await sendEther(bob, ether('3'));

            await presaleActivateFcfs(alice);
            await sendEther(dick, ether('3'));

            await uniswapRouter.addLiquidityETHShouldReceive(
                token.address,
                ether('3.6'),
                ether('162'),
                ether('162'),
                ether('3.6'),
                liquidityLock.address
            );
            await token.burnShouldReceive(ether('162')); // (162 not sent to liquidity since we're using a mock)
            const tracker = await balance.tracker(earl);
            await presaleEnd(alice, earl);
            await token.unlockShouldBeCalled();
            expect((await token.balanceOf(frank)).eq(ether('1000'))).to.be.true;
            expect((await token.balanceOf(greg)).eq(ether('1600'))).to.be.true;
            const delta = await tracker.delta();
            expect(delta.eq(ether('2.4'))).to.be.true;

            expect(await presale.isPresaleActive()).to.be.false;
            expect(await presale.wasPresaleEnded()).to.be.true;
        });

        it('should end presale successfully with partially collected funds', async () => {
            await presaleStart([bob, curtis], alice);
            await sendEther(bob, ether('2'));

            await presaleActivateFcfs(alice);
            await sendEther(dick, ether('1'));

            await uniswapRouter.addLiquidityETHShouldReceive(
                token.address,
                ether('1.8'),
                ether('81'),
                ether('81'),
                ether('1.8'),
                liquidityLock.address
            );
            await token.burnShouldReceive(ether('462')); // (300 not sold, 162 not sent to liquidity since we're using a mock)
            const tracker = await balance.tracker(earl);
            await presaleEnd(alice, earl);
            await token.unlockShouldBeCalled();
            expect((await token.balanceOf(frank)).eq(ether('1000'))).to.be.true;
            expect((await token.balanceOf(greg)).eq(ether('1600'))).to.be.true;
            const delta = await tracker.delta();
            expect(delta.eq(ether('1.2'))).to.be.true;

            expect(await presale.isPresaleActive()).to.be.false;
            expect(await presale.wasPresaleEnded()).to.be.true;
        });
    });

    context('after stoping', () => {
        beforeEach(async () => {
            await presaleStart([bob, curtis], alice);
            await presaleEnd(alice, dick);
        });

        it('should not allow investments after finished presale', async () => {
            await expectRevert(sendEther(bob, ether('3')), 'Presale is not active.');
        });

        it('should not allow restart after finished presale', async () => {
            await expectRevert(presaleStart([], alice), 'Presale was ended.');
        });
    });
});
