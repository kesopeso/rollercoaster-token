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
        const result = await farm.startFarming(token.address, token.address);
        logEvents('farming started', result);
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

    xit('should calculate harvestable reward correctly', async () => {
        await farm.stake(ether('1'), { from: bob });
        await time.increase(time.duration.days(5));
        await farm.stake(ether('1'), { from: curtis });
        await time.increase(time.duration.days(5));
        await farm.harvest(0, { from: bob });
        await time.increase(time.duration.days(4));
        const harvestable = await farm.harvestable(bob);
        expect(harvestable.toString()).to.equal(ether('5').toString());
    });

    xit('should consume normal amount of gas', async () => {
        for (let i = 0; i < 30; i++) {
            const { receipt: stakeReceipt } = await farm.stake(ether('0.0001'), { from: bob });
            console.log('stake gas', stakeReceipt.gasUsed);
            await time.increase(time.duration.days(1));
        }
        let harvestable = await farm.harvestable(bob);
        console.log(harvestable.toString());
        console.log('==========');

        let result = await farm.harvest(0, { from: bob });
        logEvents('harvest', result);
        console.log('gas', result.receipt.gasUsed);
        let harvested = await farm.harvested(bob);
        console.log(harvested.toString());
        harvestable = await farm.harvestable(bob);
        console.log(harvestable.toString());
        console.log('==========')

        result = await farm.harvest(10, { from: bob });
        logEvents('harvest', result);
        console.log('gas', result.receipt.gasUsed);
        harvested = await farm.harvested(bob);
        console.log(harvested.toString());
        harvestable = await farm.harvestable(bob);
        console.log(harvestable.toString());
        console.log('==========')

        result = await farm.harvest(1, { from: bob });
        logEvents('harvest', result);
        console.log('gas', result.receipt.gasUsed);
        harvested = await farm.harvested(bob);
        console.log(harvested.toString());
        harvestable = await farm.harvestable(bob);
        console.log(harvestable.toString());
        console.log('==========')
    });

    xit('should simulate farming successfully', async () => {
        await time.increase(time.duration.days(1));

        let result = await farm.stake(ether('1'), { from: bob });
        logEvents('bob staked', result);
        let harvestSnapshotId = await farm.harvestSnapshotId(bob);
        let snapshotsCount = await farm.snapshotsCount();
        let snapshotTimestamp = await farm.snapshotTimestamp(snapshotsCount - 1);
        console.log(harvestSnapshotId.toString(), snapshotsCount.toString(), snapshotTimestamp.toString());

        await time.increase(time.duration.days(4));

        let harvestable = await farm.harvestable(bob);
        console.log('bob harvestable', harvestable.toString());

        await time.increase(time.duration.days(1));

        result = await farm.harvest(0, { from: bob });
        logEvents('bob harvested', result);

        await time.increase(time.duration.days(1));
        result = await farm.stake(ether('1'), { from: bob });
        logEvents('bob staked', result);
        harvestSnapshotId = await farm.harvestSnapshotId(bob);
        snapshotsCount = await farm.snapshotsCount();
        snapshotTimestamp = await farm.snapshotTimestamp(snapshotsCount - 1);
        console.log(harvestSnapshotId.toString(), snapshotsCount.toString(), snapshotTimestamp.toString());

        await time.increase(time.duration.days(1));

        result = await farm.harvest(0, { from: bob });
        logEvents('bob harvested', result);

        await time.increase(time.duration.days(1));

        result = await farm.harvest(0, { from: bob });
        logEvents('bob harvested', result);
        harvestSnapshotId = await farm.harvestSnapshotId(bob);
        snapshotsCount = await farm.snapshotsCount();
        console.log(harvestSnapshotId.toString(), snapshotsCount.toString());

        await time.increase(time.duration.days(2));

        result = await farm.stake(ether('2'), { from: curtis });
        logEvents('curtis staked', result);
        harvestSnapshotId = await farm.harvestSnapshotId(curtis);
        snapshotsCount = await farm.snapshotsCount();
        snapshotTimestamp = await farm.snapshotTimestamp(snapshotsCount - 1);
        console.log(harvestSnapshotId.toString(), snapshotsCount.toString(), snapshotTimestamp.toString());

        await time.increase(time.duration.days(5));

        harvestable = await farm.harvestable(bob);
        console.log('bob harvestable', harvestable.toString());
        harvestable = await farm.harvestable(curtis);
        console.log('curtis harvestable', harvestable.toString());

        await time.increase(time.duration.days(1));

        result = await farm.harvest(1, { from: curtis });
        logEvents('curtis harvested', result);
        harvestSnapshotId = await farm.harvestSnapshotId(curtis);
        snapshotsCount = await farm.snapshotsCount();
        console.log(harvestSnapshotId.toString(), snapshotsCount.toString());

        await time.increase(time.duration.days(2));

        result = await farm.withdraw(ether('2'), { from: curtis });
        logEvents('curtis withdrew', result);
        result = await farm.harvest(1, { from: curtis });
        logEvents('curtis harvested', result);

        await time.increase(time.duration.days(2));

        result = await farm.harvest(1, { from: bob });
        logEvents('bob harvested', result);
        harvestSnapshotId = await farm.harvestSnapshotId(bob);
        snapshotsCount = await farm.snapshotsCount();
        console.log(harvestSnapshotId.toString(), snapshotsCount.toString());

        result = await farm.harvest(0, { from: bob });
        logEvents('bob harvested', result);
        harvestSnapshotId = await farm.harvestSnapshotId(bob);
        snapshotsCount = await farm.snapshotsCount();
        console.log(harvestSnapshotId.toString(), snapshotsCount.toString());
    });
});

const logEvents = (logText, result) => {
    if (result.logs.length == 0) {
        console.log(`${logText} - no events`);
        return;
    }

    for (let i = 0; i < result.logs.length; i++) {
        switch (result.logs[i].event) {
            case 'SnapshotAdded':
                const {
                    _id: snapshotId,
                    _timestamp: snapshotTimestamp,
                    _totalAmount: snapshotTotalAmount,
                } = result.logs[i].args;
                console.log(
                    `${logText} - Snapshot added ${snapshotId}: timestamp ${snapshotTimestamp}, amount ${snapshotTotalAmount.toString()}`
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
