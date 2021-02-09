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

    it('should set rewards correctly', async () => {
        let expectedReward = ether('50');
        for (let i = 0; i < 10; i++) {
            const actualReward = await farm.intervalReward();
            expect(actualReward.toString()).to.equal(expectedReward.toString());
            await time.increase(time.duration.days(10));
            expectedReward = expectedReward.div(new BN('2'));
        }
    });

    it('should set next interval correctly', async () => {
        let expectedNextInterval = await farm.nextIntervalTimestamp();
        for (let i = 0; i < 10; i++) {
            expectedNextInterval = expectedNextInterval.add(new BN('864000'));
            await time.increase(time.duration.days(10));
            const actualNextInterval = await farm.nextIntervalTimestamp();
            expect(actualNextInterval.toString()).to.equal(expectedNextInterval.toString());
        }
    });

    it('should calculate harvestable reward correctly', async () => {
        await farm.stake(ether('1'), { from: bob });
        await time.increase(time.duration.days(5));
        await farm.stake(ether('1'), { from: curtis });
        await time.increase(time.duration.days(5));
        await farm.harvest({ from: bob });
        await time.increase(time.duration.days(4));
        const harvestable = await farm.harvestable(bob);
        expect(harvestable.toString()).to.equal(ether('5').toString());
    });

    it('should consume normal amount of gas', async () => {
        for (let i = 0; i < 30; i++) {
            const { receipt: stakeReceipt } = await farm.stake(ether('0.0001'), { from: bob });
            console.log('stake gas', stakeReceipt.gasUsed);
            await time.increase(time.duration.hours(1));
        }
        for (let i = 0; i < 30; i++) {
            const { receipt: withdrawReceipt } = await farm.withdraw(ether('0.0001'), { from: bob });
            console.log('withdraw gas', withdrawReceipt.gasUsed);
            await time.increase(time.duration.hours(1));
        }
        for (let i = 0; i < 20; i++) {
            const { receipt: harvestReceipt } = await farm.harvest({ from: bob });
            console.log('harvest gas', harvestReceipt.gasUsed);
            await time.increase(time.duration.hours(12));
        }
        for (let i = 0; i < 20; i++) {
            const { receipt: claimReceipt } = await farm.claim({ from: bob });
            console.log('claim gas', claimReceipt.gasUsed);
            await time.increase(time.duration.hours(12));
        }
        for (let i = 0; i < 10; i++) {
            const { receipt: stakeReceipt } = await farm.stake(ether('0.0001'), { from: bob });
            console.log('stake gas', stakeReceipt.gasUsed);
            await time.increase(time.duration.hours(20));
        }
        for (let i = 0; i < 10; i++) {
            const { receipt: withdrawReceipt } = await farm.withdraw(ether('0.0001'), { from: bob });
            console.log('withdraw gas', withdrawReceipt.gasUsed);
            await time.increase(time.duration.hours(20));
        }
        for (let i = 0; i < 3; i++) {
            const { receipt: harvestReceipt } = await farm.harvest({ from: bob });
            console.log('harvest gas', harvestReceipt.gasUsed);
            await time.increase(time.duration.hours(12));
        }
    });

    it('should simulate farming successfully', async () => {
        let result = await farm.stake(ether('1'), { from: bob });
        logEvents('bob staked', result);

        await time.increase(time.duration.days(5));

        result = await farm.stake(ether('1'), { from: curtis });
        logEvents('curtis staked', result);

        await time.increase(time.duration.days(5));

        result = await farm.harvest({ from: bob });
        logEvents('bob harvested', result);

        await time.increase(time.duration.days(2));

        let bobAmount = await token.balanceOf(bob);
        result = await farm.claim({ from: bob });
        bobAmount = (await token.balanceOf(bob)).sub(bobAmount);
        console.log('bob claimed amount', bobAmount.toString());
        logEvents('bob claimed', result);

        await time.increase(time.duration.days(2));

        result = await farm.claimable(bob);
        console.log('bob claimable', result.toString());
        result = await farm.harvestable(bob);
        console.log('bob harvestable', result.toString());

        await time.increase(time.duration.days(2));

        result = await farm.withdraw(ether('1'), { from: bob });
        logEvents('bob withdrew', result);

        await time.increase(time.duration.days(2));

        result = await farm.claimable(bob);
        console.log('bob claimable', result.toString());

        await time.increase(time.duration.days(1));

        result = await farm.claim({ from: bob });
        logEvents('bob claimed', result);

        await time.increase(time.duration.days(1));

        result = await farm.withdraw(ether('1'), { from: curtis });
        logEvents('curtis withdrew', result);

        await time.increase(time.duration.days(1));
        result = await farm.stake(ether('1'), { from: curtis });
        logEvents('curtis staked', result);

        await time.increase(time.duration.days(15));
        result = await farm.harvestable(bob);
        console.log('bob harvestable', result.toString());
        result = await farm.harvestable(curtis);
        console.log('curtis harvestable', result.toString());

        await time.increase(time.duration.days(1));
        result = await farm.harvest({ from: bob });
        logEvents('bob harvested', result);
        result = await farm.harvest({ from: curtis });
        logEvents('curtis harvested', result);
    });
});

const logEvents = (logText, result) => {
    for (let i = 0; i < result.logs.length; i++) {
        switch (result.logs[i].event) {
            case 'SnapshotAdded':
                const {
                    _id: snapshotId,
                    _intervalId: snapshotIntervalId,
                    _timestamp: snapshotTimestamp,
                    _totalAmount: snapshotTotalAmount,
                } = result.logs[i].args;
                console.log(
                    `${logText} - Snapshot added ${snapshotId}: interval ${snapshotIntervalId}, timestamp ${snapshotTimestamp}, amount ${snapshotTotalAmount.toString()}`
                );
                break;

            case 'HarvestCreated':
                const {
                    _staker: staker,
                    _id: addHcIdx,
                    _timestamp: addHcTimestamp,
                    _amount: addHcAmount,
                } = result.logs[i].args;
                console.log(
                    `${logText} - Harvest created ${addHcIdx} for ${staker}: timestamp ${addHcTimestamp}, amount ${addHcAmount}`
                );
                break;

            case 'RewardClaimed':
                const {
                    _staker: rcStaker,
                    _harvestId: rcHarvestChunkIdx,
                    _timestamp: rcTimestamp,
                    _amount: rcAmount,
                } = result.logs[i].args;
                console.log(
                    `${logText} - Reward claimed from harvest id ${rcHarvestChunkIdx} for ${rcStaker}: timestamp ${rcTimestamp}, amount ${rcAmount}`
                );
                break;
        }
    }
};
