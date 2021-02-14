const { expect } = require('chai');
const { BN, ether, time, balance } = require('@openzeppelin/test-helpers');
const TokenMock = artifacts.require('TokenMock');
const Farm = artifacts.require('Farm');

contract('Farm', (accounts) => {
    const [alice, bob, curtis] = accounts;
    let token;
    let farm;

    beforeEach(async () => {
        token = await TokenMock.new(alice, ether('110'));
        farm = await Farm.new();
        await farm.initialize(alice);

        await token.transfer(farm.address, ether('100'));
        await token.transfer(bob, ether('5'));
        await token.transfer(curtis, ether('5'));
        await token.approve(farm.address, ether('100'), { from: bob });
        await token.approve(farm.address, ether('100'), { from: curtis });
        await farm.startFarming(token.address, token.address);
    });

    it('should set rewards correctly if current time over last calculated interval', async () => {
        await time.increase(time.duration.days(10));
        const expectedReward = ether('16');
        const actualReward = await farm.intervalReward();
        expect(actualReward.toString()).to.equal(expectedReward.toString());
    });

    it('should set next interval correctly if current time over last calculated interval', async () => {
        const expectedNextInterval = (await farm.nextIntervalTimestamp()).add(new BN('864000'));
        await time.increase(time.duration.days(10));
        const actualNextInterval = await farm.nextIntervalTimestamp();
        expect(actualNextInterval.toString()).to.equal(expectedNextInterval.toString());
    });

    it('should calculate harvestable reward correctly', async () => {
        await farm.stake(ether('1'), { from: bob });
        await time.increase(time.duration.days(5));
        let harvestable = await farm.harvestable(bob);
        expect(harvestable.gt(ether('9.9999'))).to.be.true;
        expect(harvestable.lt(ether('10.0001'))).to.be.true;

        await farm.stake(ether('1'), { from: curtis });
        await time.increase(time.duration.days(5));
        harvestable = await farm.harvestable(bob);
        expect(harvestable.gt(ether('14.9999'))).to.be.true;
        expect(harvestable.lt(ether('15.0001'))).to.be.true;
        await farm.harvest({ from: bob });

        await time.increase(time.duration.days(4));
        harvestable = await farm.harvestable(bob);
        expect(harvestable.gt(ether('3.1999'))).to.be.true;
        expect(harvestable.lt(ether('3.2001'))).to.be.true;
    });

    it('should simulate farming successfully', async () => {
        await time.increase(time.duration.days(1));
        await farm.stake(ether('1'), { from: bob });

        await time.increase(time.duration.days(4));
        let harvestable = await farm.harvestable(bob);
        expect(harvestable.gt(ether('7.9999'))).to.be.true;
        expect(harvestable.lt(ether('8.0001'))).to.be.true;

        await time.increase(time.duration.days(1));
        await farm.harvest({ from: bob });
        let harvested = await farm.harvested(bob);
        expect(harvested.gt(ether('9.9999'))).to.be.true;
        expect(harvested.lt(ether('10.0001'))).to.be.true;
        harvestable = await farm.harvestable(bob);
        expect(harvestable.toString()).to.equal(ether('0').toString());
        let claimable = await farm.claimable(bob);
        expect(claimable.toString()).to.equal(ether('0').toString());

        await time.increase(time.duration.days(1));
        await farm.stake(ether('1'), { from: curtis });

        await time.increase(time.duration.days(1));
        harvestable = await farm.harvestable(bob);
        expect(harvestable.gt(ether('2.9999'))).to.be.true;
        expect(harvestable.lt(ether('3.0001'))).to.be.true;
        claimable = await farm.claimable(bob);
        expect(claimable.gt(ether('1.9999'))).to.be.true;
        expect(claimable.lt(ether('2.0001'))).to.be.true;

        await time.increase(time.duration.days(3));
        harvestable = await farm.harvestable(bob);
        expect(harvestable.gt(ether('5.7999'))).to.be.true;
        expect(harvestable.lt(ether('5.8001'))).to.be.true;
        await farm.withdraw(ether('1'), { from: bob });

        await time.increase(time.duration.days(6));
        harvestable = await farm.harvestable(bob);
        expect(harvestable.gt(ether('5.7999'))).to.be.true;
        expect(harvestable.lt(ether('5.8001'))).to.be.true;
        claimable = await farm.claimable(bob);
        expect(claimable.gt(ether('9.9999'))).to.be.true;
        expect(claimable.lt(ether('10.0001'))).to.be.true;
        harvestable = await farm.harvestable(curtis);
        expect(harvestable.gt(ether('13.3999'))).to.be.true;
        expect(harvestable.lt(ether('13.4001'))).to.be.true;
        const bobStartBalance = await token.balanceOf(bob);
        await farm.claim({ from: bob });
        const bobBalanceDelta = (await token.balanceOf(bob)).sub(bobStartBalance);
        expect(bobBalanceDelta.gt(ether('9.9999'))).to.be.true;
        expect(bobBalanceDelta.lt(ether('10.0001'))).to.be.true;

        await time.increase(time.duration.days(4));
        harvestable = await farm.harvestable(curtis);
        expect(harvestable.gt(ether('19.4799'))).to.be.true;
        expect(harvestable.lt(ether('19.4801'))).to.be.true;
    });
});
