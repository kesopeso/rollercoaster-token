// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./interfaces/IFarm.sol";
import "./interfaces/IFarmActivator.sol";

contract Farm is Initializable, IFarm, IFarmActivator {
    event SnapshotAdded(uint256 _id, uint256 _intervalId, uint256 _timestamp, uint256 _totalAmount);
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
        uint256[] singleSnapshotIds;
        uint256[] totalSnapshotIds;
        uint256[] timestamps;
        uint256[] claimed;
        uint256[] total;
    }

    address private activator;
    bool private isFarmingStarted;
    uint256 private totalReward;
    uint256 private currentReward;
    uint256 private currentIntervalId;
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

    function harvest() external override farmingStarted {
        addIntervalSnapshots(true);

        uint256 harvestableAmount = harvestable(msg.sender);
        if (harvestableAmount == 0) {
            return;
        }

        harvests[msg.sender].count++;
        harvests[msg.sender].claimed.push(0);
        harvests[msg.sender].timestamps.push(block.timestamp);
        harvests[msg.sender].total.push(harvestableAmount);
        harvests[msg.sender].singleSnapshotIds.push(singleSnapshots[msg.sender].count - 1);
        harvests[msg.sender].totalSnapshotIds.push(totalSnapshots.count - 1);
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

    function harvestable(address _staker) public view override returns (uint256) {
        if (singleSnapshots[_staker].count == 0) {
            return 0;
        }

        // SSS = single snapshop, TSS = total snapshot, TS = timestamp
        uint256 firstSSS = 0;
        uint256 firstTSS = singleSnapshots[_staker].totalSnapshotIds[firstSSS];
        uint256 firstTS = totalSnapshots.timestamps[firstTSS];
        if (harvests[_staker].count > 0) {
            uint256 lastHarvestId = harvests[_staker].count - 1;
            firstSSS = harvests[_staker].singleSnapshotIds[lastHarvestId];
            firstTSS = harvests[_staker].totalSnapshotIds[lastHarvestId];
            firstTS = harvests[_staker].timestamps[lastHarvestId];
        }
        uint256 lastSSS = singleSnapshots[_staker].count - 1;
        uint256 lastTSS = totalSnapshots.count - 1;

        uint256 harvestableAmount = 0;
        for (uint256 i = firstSSS; i < singleSnapshots[_staker].count; i++) {
            uint256 staked = singleSnapshots[_staker].staked[i];
            if (staked == 0) {
                continue;
            }

            uint256 j = i == firstSSS ? firstTSS : singleSnapshots[_staker].totalSnapshotIds[i];
            uint256 toTSS = i < lastSSS ? singleSnapshots[_staker].totalSnapshotIds[i + 1] : totalSnapshots.count;
            for (j; j < toTSS; j++) {
                uint256 startTime = j > firstTSS ? totalSnapshots.timestamps[j] : firstTS;
                uint256 endTime = j < lastTSS ? totalSnapshots.timestamps[j + 1] : block.timestamp;
                uint256 snapshotHarvestableAmount =
                    totalSnapshots.reward[j].mul(endTime.sub(startTime)).mul(staked).div(
                        REWARD_HALVING_INTERVAL.mul(totalSnapshots.staked[j])
                    );
                harvestableAmount = harvestableAmount.add(snapshotHarvestableAmount);
            }
        }

        return harvestableAmount;
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
            currentIntervalId++;

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
        emit SnapshotAdded(totalSnapshots.count - 1, currentIntervalId, _timestamp, _staked);
    }

    function addSingleSnapshot(uint256 _amount) private {
        singleSnapshots[msg.sender].count++;
        singleSnapshots[msg.sender].staked.push(_amount);
        singleSnapshots[msg.sender].totalSnapshotIds.push(totalSnapshots.count - 1);
    }

    uint256[38] private __gap;
}
