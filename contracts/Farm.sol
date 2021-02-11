// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./interfaces/IFarm.sol";
import "./interfaces/IFarmActivator.sol";

contract Farm is Initializable, IFarm, IFarmActivator {
    event SnapshotAdded(uint256 _id, uint256 _timestamp, uint256 _totalAmount);
    event HarvestCreated(address indexed _staker, uint256 _id, uint256 _timestamp, uint256 _amount);
    event RewardClaimed(address indexed _staker, uint256 indexed _harvestId, uint256 _timestamp, uint256 _amount);

    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    uint256 public constant REWARD_HALVING_INTERVAL = 10 days;
    uint256 public constant HARVEST_INTERVAL = 1 days;

    struct TotalSnapshots {
        uint256 count;
        uint256[] timestamps;
        uint256[] staked;
        uint256[] reward;
    }

    struct SingleSnapshots {
        uint256 count;
        uint256[] totalSnapshotIds;
        uint256[] staked;
    }

    struct Harvests {
        uint256 count;
        uint256 firstUnclaimedId;
        uint256 totalSnapshotId;
        uint256[] timestamps;
        uint256[] claimed;
        uint256[] total;
    }

    address private activator;
    bool private isFarmingStarted;
    uint256 private totalReward;
    uint256 private currentReward;
    IERC20 private rewardToken;
    IERC20 private farmToken;
    TotalSnapshots private totalSnapshots;
    mapping(address => SingleSnapshots) private singleSnapshots;
    mapping(address => Harvests) private harvests;

    function initialize(address _activator) external initializer {
        __Farm_init(_activator);
    }

    function __Farm_init(address _activator) internal initializer {
        __Farm_init_unchained(_activator);
    }

    function __Farm_init_unchained(address _activator) internal initializer {
        activator = _activator;
    }

    modifier onlyActivator() {
        require(msg.sender == activator, "Only activator allowed.");
        _;
    }

    modifier farmingNotStarted() {
        require(!isFarmingStarted, "Farming was already started.");
        _;
    }

    modifier farmingStarted() {
        require(isFarmingStarted, "Farming not started yet.");
        _;
    }

    modifier rewardTokensDeposited(address _rewardToken) {
        uint256 balance = IERC20(_rewardToken).balanceOf(address(this));
        require(balance > 0, "Reward tokens are not deposited.");
        _;
    }

    modifier stakeAddressNotContract() {
        require(!address(msg.sender).isContract(), "Staking from contracts is not allowed.");
        _;
    }

    modifier stakeAmountValid(uint256 _amount) {
        require(_amount > 0, "Staking amount must be bigger than 0.");
        require(
            _amount <= farmToken.allowance(msg.sender, address(this)),
            "Farm is not allowed to transfer the desired staking amount."
        );
        _;
    }

    modifier withdrawAmountValid(uint256 _amount) {
        require(_amount <= singleStaked(msg.sender), "Withdraw amount too big.");
        _;
    }

    function farmingActive() external view override returns (bool) {
        return isFarmingStarted;
    }

    function totalRewardSupply() external view override returns (uint256) {
        return totalReward;
    }

    function intervalReward() external view override returns (uint256) {
        if (totalSnapshots.count == 0) {
            return 0;
        }
        uint256 intervalIdx = block.timestamp.sub(totalSnapshots.timestamps[0]).div(REWARD_HALVING_INTERVAL);
        return totalReward.div(2**intervalIdx.add(1));
    }

    function nextIntervalTimestamp() external view override returns (uint256) {
        if (totalSnapshots.count == 0) {
            return 0;
        }
        uint256 secondsElapsedInCurrentInterval =
            block.timestamp.sub(totalSnapshots.timestamps[0]).mod(REWARD_HALVING_INTERVAL);
        uint256 secondsUntilNextInterval = REWARD_HALVING_INTERVAL.sub(secondsElapsedInCurrentInterval);
        return block.timestamp.add(secondsUntilNextInterval);
    }

    function rewardTokenAddress() external view override returns (address) {
        return address(rewardToken);
    }

    function farmTokenAddress() external view override returns (address) {
        return address(farmToken);
    }

    function singleStaked(address _staker) public view override returns (uint256) {
        uint256 count = singleSnapshots[_staker].count;
        return count > 0 ? singleSnapshots[_staker].staked[count - 1] : 0;
    }

    function totalStaked() public view override returns (uint256) {
        uint256 count = totalSnapshots.count;
        return count > 0 ? totalSnapshots.staked[count - 1] : 0;
    }

    function startFarming(address _rewardToken, address _farmToken)
        external
        override
        onlyActivator
        farmingNotStarted
        rewardTokensDeposited(_rewardToken)
    {
        rewardToken = IERC20(_rewardToken);
        farmToken = IERC20(_farmToken);
        totalReward = rewardToken.balanceOf(address(this));
        currentReward = totalReward.div(2);
        addTotalSnapshot(block.timestamp, 0);
        isFarmingStarted = true;
    }

    function stake(uint256 _amount) external override farmingStarted stakeAddressNotContract stakeAmountValid(_amount) {
        farmToken.transferFrom(msg.sender, address(this), _amount);
        addIntervalSnapshots(false);
        addTotalSnapshot(block.timestamp, totalStaked().add(_amount));
        addSingleSnapshot(singleStaked(msg.sender).add(_amount));
    }

    function withdraw(uint256 _amount) external override farmingStarted withdrawAmountValid(_amount) {
        farmToken.transfer(msg.sender, _amount);
        addIntervalSnapshots(false);
        addTotalSnapshot(block.timestamp, totalStaked().sub(_amount));
        addSingleSnapshot(singleStaked(msg.sender).sub(_amount));
    }

    function harvest(uint256 _maxSnapshots) external override farmingStarted {
        addIntervalSnapshots(true);

        (uint256 harvestableAmount, uint256 snapshotId) = harvestableToTake(msg.sender, _maxSnapshots);
        if (harvestableAmount == 0) {
            return;
        }

        harvests[msg.sender].count++;
        harvests[msg.sender].claimed.push(0);
        harvests[msg.sender].timestamps.push(block.timestamp);
        harvests[msg.sender].total.push(harvestableAmount);
        harvests[msg.sender].totalSnapshotId = snapshotId;
        emit HarvestCreated(msg.sender, harvests[msg.sender].count - 1, block.timestamp, harvestableAmount);
    }

    function claim() external override farmingStarted {
        uint256 claimableAmount = 0;
        uint256 idOffset = harvests[msg.sender].firstUnclaimedId;
        uint256[] memory parts = claimableHarvests(msg.sender);

        for (uint256 i = 0; i < parts.length; i++) {
            if (parts[i] == 0) {
                break;
            }

            uint256 id = i.add(idOffset);
            harvests[msg.sender].claimed[id] = harvests[msg.sender].claimed[id].add(parts[i]);
            if (harvests[msg.sender].claimed[id] >= harvests[msg.sender].total[id]) {
                harvests[msg.sender].firstUnclaimedId++;
            }

            claimableAmount = claimableAmount.add(parts[i]);
            emit RewardClaimed(msg.sender, id, block.timestamp, parts[i]);
        }

        if (claimableAmount > 0) {
            rewardToken.transfer(msg.sender, claimableAmount);
        }
    }

    function harvestable(address _staker) external view override returns (uint256) {
        if (singleSnapshots[_staker].count == 0) {
            return 0;
        }

        uint256 amount = 0;
        uint256 lastSingleSnapshotId = singleSnapshots[_staker].count - 1;
        uint256 lastTotalSnapshotId = totalSnapshots.count - 1;

        for (uint256 i = 0; i < singleSnapshots[_staker].count; i++) {
            uint256 staked = singleSnapshots[_staker].staked[i];
            if (staked == 0) {
                continue;
            }
            uint256 startSnapshotId =
                singleSnapshots[_staker].totalSnapshotIds[i] > harvests[_staker].totalSnapshotId
                    ? singleSnapshots[_staker].totalSnapshotIds[i]
                    : harvests[_staker].totalSnapshotId;
            uint256 endSnapshotId =
                i < lastSingleSnapshotId ? singleSnapshots[_staker].totalSnapshotIds[i + 1] : totalSnapshots.count;
            for (uint256 j = startSnapshotId; j < endSnapshotId; j++) {
                uint256 endTime = j < lastTotalSnapshotId ? totalSnapshots.timestamps[j + 1] : block.timestamp;
                amount = amount.add(
                    totalSnapshots.reward[j]
                        .mul(endTime - totalSnapshots.timestamps[j])
                        .mul(staked)
                        .div(REWARD_HALVING_INTERVAL)
                        .div(totalSnapshots.staked[j])
                );
            }
        }

        return amount;
    }

    function claimable(address _staker) external view override returns (uint256) {
        uint256[] memory parts = claimableHarvests(_staker);
        uint256 claimableAmount = 0;
        for (uint256 i = 0; i < parts.length; i++) {
            claimableAmount = claimableAmount.add(parts[i]);
        }
        return claimableAmount;
    }

    function harvested(address _staker) external view override returns (uint256) {
        uint256 harvestedAmount = 0;
        for (uint256 i = harvests[_staker].firstUnclaimedId; i < harvests[_staker].count; i++) {
            harvestedAmount = harvestedAmount.add(harvests[_staker].total[i].sub(harvests[_staker].claimed[i]));
        }
        return harvestedAmount;
    }

    function snapshotsCount() external view override returns (uint256) {
        return totalSnapshots.count;
    }

    function snapshotTimestamp(uint256 _snapshotId) external view override returns (uint256) {
        return totalSnapshots.timestamps[_snapshotId];
    }

    function harvestSnapshotId(address _staker) external view override returns (uint256) {
        if (singleSnapshots[_staker].count == 0) {
            return 0;
        }

        if (harvests[_staker].count == 0) {
            return singleSnapshots[_staker].totalSnapshotIds[0];
        }

        return harvests[_staker].totalSnapshotId;
    }

    function harvestChunk(address _staker, uint56 _id)
        external
        view
        override
        returns (
            uint256 timestamp,
            uint256 claimed,
            uint256 total
        )
    {
        bool harvestExists = harvests[_staker].count > _id;
        timestamp = harvestExists ? harvests[_staker].timestamps[_id] : 0;
        claimed = harvestExists ? harvests[_staker].claimed[_id] : 0;
        total = harvestExists ? harvests[_staker].total[_id] : 0;
    }

    function harvestableToTake(address _staker, uint256 _maxSnapshots)
        private
        view
        returns (uint256 amount, uint256 snapshotId)
    {
        amount = 0;
        snapshotId = harvests[_staker].totalSnapshotId;

        if (singleSnapshots[_staker].count == 0) {
            return (amount, snapshotId);
        }

        uint256 lastSingleSnapshotId = singleSnapshots[_staker].count - 1;
        uint256 lastTotalSnapshotId = totalSnapshots.count - 1;
        uint256 maxSnapshots = _maxSnapshots == 0 ? 2**256 - 1 : _maxSnapshots;
        uint256 snapshotsExecuted = 0;

        for (uint256 i = 0; i < singleSnapshots[_staker].count; i++) {
            uint256 staked = singleSnapshots[_staker].staked[i];
            if (staked == 0) {
                continue;
            }
            uint256 startSnapshotId =
                singleSnapshots[_staker].totalSnapshotIds[i] > harvests[_staker].totalSnapshotId
                    ? singleSnapshots[_staker].totalSnapshotIds[i]
                    : harvests[_staker].totalSnapshotId;
            uint256 endSnapshotId =
                i < lastSingleSnapshotId ? singleSnapshots[_staker].totalSnapshotIds[i + 1] : lastTotalSnapshotId;
            for (uint256 j = startSnapshotId; j < endSnapshotId; j++) {
                if (snapshotsExecuted >= maxSnapshots) {
                    break;
                }
                uint256 endTime = j < lastTotalSnapshotId ? totalSnapshots.timestamps[j + 1] : block.timestamp;
                amount = amount.add(
                    totalSnapshots.reward[j]
                        .mul(endTime - totalSnapshots.timestamps[j])
                        .mul(staked)
                        .div(REWARD_HALVING_INTERVAL)
                        .div(totalSnapshots.staked[j])
                );
                snapshotId = j + 1;
                snapshotsExecuted++;
            }
        }

        return (amount, snapshotId);
    }

    function claimableHarvests(address _staker) private view returns (uint256[] memory) {
        if (harvests[_staker].count == 0 || harvests[_staker].firstUnclaimedId >= harvests[_staker].count) {
            return new uint256[](0);
        }

        uint256 count = harvests[_staker].count.sub(harvests[_staker].firstUnclaimedId);
        uint256[] memory parts = new uint256[](count);

        for (uint256 i = harvests[_staker].firstUnclaimedId; i < harvests[_staker].count; i++) {
            uint256 daysSinceHarvest = block.timestamp.sub(harvests[_staker].timestamps[i]).div(HARVEST_INTERVAL);
            uint256 percentClaimable = daysSinceHarvest >= 10 ? 100 : daysSinceHarvest.mul(10);
            uint256 totalClaimableAmount = harvests[_staker].total[i].mul(percentClaimable).div(100);
            parts[i] = harvests[_staker].claimed[i] < totalClaimableAmount
                ? totalClaimableAmount.sub(harvests[_staker].claimed[i])
                : 0;
        }

        return parts;
    }

    function addIntervalSnapshots(bool shouldAddOnEqualTimestamps) private {
        uint256 firstSnapshotTimestamp = totalSnapshots.timestamps[0];
        uint256 lastSnapshotTimestamp = totalSnapshots.timestamps[totalSnapshots.count - 1];
        uint256 currentTotalStaked = totalStaked();

        while (true) {
            uint256 timeElapsed = lastSnapshotTimestamp.sub(firstSnapshotTimestamp);
            uint256 intervalElapsed = timeElapsed.mod(REWARD_HALVING_INTERVAL);
            uint256 timeUntilNextSnapshot = REWARD_HALVING_INTERVAL.sub(intervalElapsed);
            lastSnapshotTimestamp = lastSnapshotTimestamp.add(timeUntilNextSnapshot);

            if (lastSnapshotTimestamp > block.timestamp) {
                return;
            }

            currentReward = currentReward.div(2);

            if (shouldAddOnEqualTimestamps || lastSnapshotTimestamp < block.timestamp) {
                addTotalSnapshot(lastSnapshotTimestamp, currentTotalStaked);
            }

            if (lastSnapshotTimestamp == block.timestamp) {
                return;
            }
        }
    }

    function addTotalSnapshot(uint256 _timestamp, uint256 _staked) private {
        totalSnapshots.count++;
        totalSnapshots.timestamps.push(_timestamp);
        totalSnapshots.staked.push(_staked);
        totalSnapshots.reward.push(currentReward);
        emit SnapshotAdded(totalSnapshots.count - 1, _timestamp, _staked);
    }

    function addSingleSnapshot(uint256 _amount) private {
        singleSnapshots[msg.sender].count++;
        singleSnapshots[msg.sender].staked.push(_amount);
        singleSnapshots[msg.sender].totalSnapshotIds.push(totalSnapshots.count - 1);
    }

    uint256[38] private __gap;
}
