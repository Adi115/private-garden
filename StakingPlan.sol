// SPDX-License-Identifier: MIT

//Deposit Fee Left
pragma solidity ^0.8.4;

import "./PrivateGardenToken.sol";
import "./IUSDT.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract StakingPlan is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _planId;

    PrivateGardenToken private PVNG;
    IUSDT private USDT;

    uint256 public constant REWARD_PER_TOKEN = 4.2 * 10**18; // 4.2 rewards per token deposited

    uint256 public constant DEPOSIT_Fee_PERCENTAGE = 5; // deposit fee
    uint256 public constant WITHDRAW_Fee_PERCENTAGE = 10; // withdraw fee
    uint256 public constant DAY_IN_SECONDS = 24 * 60 * 60;

    address public company;

    // struct representing a plan
    struct Plan {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 maxWithdrawal;
        uint256 duration; // duration of the plan in days
        uint256 dailyReward; // daily reward in reward tokens
        uint256 monthlyReward; // monthly reward in reward tokens
        uint256 totalRoi; // total rewards in reward tokens
        bool capitalReturn; // capital returned to its rightful owners
    }

    struct RookiePlan {
        uint256 amount; // amount deposited
        uint256 withdrawAmount; // amoutn withdrawn
        uint256 purchaseTimestamp; // amount deposited timestamp
        uint256 lastWithdrawalTimestamp; // last withdrawn timestamp
        uint256 lastClaimedTimestamp;
        uint256 claimedReward; // duration of the plan in days
    }

    struct ProPlan {
        uint256 amount; // amount deposited
        uint256 withdrawAmount; // amoutn withdrawn
        uint256 purchaseTimestamp; // amount deposited timestamp
        uint256 lastWithdrawalTimestamp; // last withdrawn timestamp
        uint256 claimedReward; // duration of the plan in days
    }

    struct MasterPlan {
        uint256 amount;
        uint256 purchaseTimestamp;
        uint256 claimedReward; // duration of the plan in days
        bool capitalReturned; // daily reward in reward tokens
    }

    // mapping from plan IDs to plan details
    mapping(uint256 => Plan) public plans;

    // Maps addresses to the amount of tokens they have staked
    mapping(address => mapping(uint256 => RookiePlan)) public rookieStakes;

    // Maps addresses to the amount of tokens they have staked
    mapping(address => mapping(uint256 => ProPlan)) public proStakes;

    // Maps addresses to the amount of tokens they have staked
    mapping(address => mapping(uint256 => MasterPlan)) public masterStakes;

    uint256 public totalFees;

    // Events
    event Staked(
        address staker,
        uint256 amount,
        uint256 unlockTimestamp,
        uint256 planId,
        uint256 fee
    );
    event Unstaked(address staker, uint256 amount, uint256 planId);
    event RewardClaimed(address staker, uint256 amount);

    // Constructor
    constructor(
        address _pvng,
        address _usdt,
        address _company
    ) {
        PVNG = PrivateGardenToken(_pvng);
        USDT = IUSDT(_usdt);
        company = _company;
        plans[1] = Plan(50, 25000, 4200e6, 90, 40, 120, 36, true); //40 equals to 0.4%
        plans[2] = Plan(1000, 25000, 4200e6, 180, 46, 140, 84, true);
        plans[3] = Plan(1000, 85000, 4200e6, 320, 75, 227, 204, false);
    }

    // Stake tokens 10
    function rookieStake(uint256 tokenAmountToStake) public {
        _planId.increment();
        uint256 id = _planId.current();

        // check stateAmount > minAmount
        require(
            tokenAmountToStake >= plans[1].minAmount * 1e6,
            "Specify an amount of token greater than minimum amount of Rookie Plan"
        );

        // check stakeAmount <= maxAmount
        require(
            tokenAmountToStake <= plans[1].maxAmount * 1e6,
            "Specify an amount of token less than maximum amount of Rookie Plan"
        );

        require(
            rookieStakes[msg.sender][id].amount + tokenAmountToStake < 85000e6,
            "Maximum 85000 USDT can be deposited per wallet"
        );

        // find userBalance
        uint256 userBalance = USDT.balanceOf(msg.sender);

        // check userBalance should be greater or equal to tokenAmountToStake
        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        totalFees = totalFees + fee;

        uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 reward = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10**(6 - 18 + 18);

        rookieStakes[msg.sender][id].amount += stakeAmount;
        // @note- attention to line 135
        rookieStakes[msg.sender][id].purchaseTimestamp = block.timestamp;

        // transfer the usdt token from user to this contract
        bool sent = USDT.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        PVNG.mint(msg.sender, reward);

        emit Staked(
            msg.sender,
            stakeAmount,
            rookieStakes[msg.sender][id].purchaseTimestamp,
            2,
            fee
        );
    }

    function updateRookieStake(uint256 tokenAmountToStake, uint256 id) public {
        RookiePlan storage rStake = rookieStakes[msg.sender][id];

        require(rStake.amount > 0, "No amount previously staked");

        require(tokenAmountToStake <= plans[1].minAmount * 1e6);

        require(rStake.amount + tokenAmountToStake <= plans[1].maxAmount * 1e6);

        uint256 userBalance = USDT.balanceOf(msg.sender);

        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        // uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        // totalFees = totalFees + fee;

        // uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 reward = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10**(6 - 18 + 18);

        rookieStakes[msg.sender][id].amount += tokenAmountToStake;

        // transfer the usdt token from user to this contract
        bool sent = USDT.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        PVNG.mint(msg.sender, reward);

        emit Staked(
            msg.sender,
            tokenAmountToStake,
            rookieStakes[msg.sender][id].purchaseTimestamp,
            2,
            0
        );
    }

    // Stake tokens
    function proStake(uint256 tokenAmountToStake) public {
        _planId.increment();
        uint256 id = _planId.current();

        require(
            tokenAmountToStake >= plans[2].minAmount * 1e6,
            "Specify an amount of token greater than minimum amount of Rookie Plan"
        );

        // check stakeAmount <= maxAmount
        require(
            tokenAmountToStake <= plans[2].maxAmount * 1e6,
            "Specify an amount of token less than maximum amount of Rookie Plan"
        );

        require(
            proStakes[msg.sender][id].amount + tokenAmountToStake < 85000e6,
            "Maximum 85000 USDT can be deposited per wallet"
        );

        // find userBalance
        uint256 userBalance = USDT.balanceOf(msg.sender);

        // check userBalance should be greater or equal to tokenAmountToStake
        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        totalFees = totalFees + fee;

        uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 reward = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10**(6 - 18 + 18);

        proStakes[msg.sender][id].amount += stakeAmount;
        proStakes[msg.sender][id].purchaseTimestamp = block.timestamp;

        // transfer the usdt token from user to this contract
        bool sent = USDT.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        PVNG.mint(msg.sender, reward);

        emit Staked(
            msg.sender,
            stakeAmount,
            proStakes[msg.sender][id].purchaseTimestamp,
            2,
            fee
        );
    }

    function updateProStake(uint256 tokenAmountToStake, uint256 id) public {
        ProPlan storage pStakes = proStakes[msg.sender][id];

        require(pStakes.amount > 0, "No amount previously staked");

        require(tokenAmountToStake <= plans[1].minAmount * 1e6);

        require(
            pStakes.amount + tokenAmountToStake <= plans[1].maxAmount * 1e6
        );

        uint256 userBalance = USDT.balanceOf(msg.sender);

        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        // uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        // totalFees = totalFees + fee;

        // uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 reward = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10**(6 - 18 + 18);

        proStakes[msg.sender][id].amount += tokenAmountToStake;

        // transfer the usdt token from user to this contract
        bool sent = USDT.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        PVNG.mint(msg.sender, reward);

        emit Staked(
            msg.sender,
            tokenAmountToStake,
            rookieStakes[msg.sender][id].purchaseTimestamp,
            2,
            0
        );
    }

    // Stake tokens
    function masterStake(uint256 tokenAmountToStake) public {
        _planId.increment();
        uint256 id = _planId.current();

        require(
            tokenAmountToStake >= plans[3].minAmount * 1e6,
            "Specify an amount of token greater than minimum amount of Rookie Plan"
        );

        // check stakeAmount <= maxAmount
        require(
            tokenAmountToStake <= plans[3].maxAmount * 1e6,
            "Specify an amount of token less than maximum amount of Rookie Plan"
        );

        require(
            masterStakes[msg.sender][id].amount + tokenAmountToStake < 85000e6,
            "Maximum 85000 USDT can be deposited per wallet"
        );

        // find userBalance
        uint256 userBalance = USDT.balanceOf(msg.sender);

        // check userBalance should be greater or equal to tokenAmountToStake
        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        totalFees = totalFees + fee;

        uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 reward = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10**(6 - 18 + 18);

        masterStakes[msg.sender][id].amount += stakeAmount;
        masterStakes[msg.sender][id].purchaseTimestamp = block.timestamp;
        masterStakes[msg.sender][id].capitalReturned = false;

        // transfer the usdt token from user to this contract
        bool sent = USDT.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        PVNG.mint(msg.sender, reward);

        emit Staked(
            msg.sender,
            stakeAmount,
            masterStakes[msg.sender][id].purchaseTimestamp,
            3,
            fee
        );
    }

    function updateMasterStake(uint256 tokenAmountToStake, uint256 id) public {
        MasterPlan storage mStakes = masterStakes[msg.sender][id];

        require(mStakes.amount > 0, "No amount previously staked");

        require(tokenAmountToStake <= plans[1].minAmount * 1e6);

        require(
            mStakes.amount + tokenAmountToStake <= plans[1].maxAmount * 1e6
        );

        uint256 userBalance = USDT.balanceOf(msg.sender);

        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        // uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        // totalFees = totalFees + fee;

        // uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 reward = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10**(6 - 18 + 18);

        mStakes.amount += tokenAmountToStake;

        // transfer the usdt token from user to this contract
        bool sent = USDT.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        PVNG.mint(msg.sender, reward);

        emit Staked(
            msg.sender,
            tokenAmountToStake,
            rookieStakes[msg.sender][id].purchaseTimestamp,
            2,
            0
        );
    }

    // UnStake tokens
    function rookieUnStake(uint256 withdrawAmount, uint256 id) public {
        RookiePlan storage rStakes = rookieStakes[msg.sender][id];
        require(rStakes.amount > 0, "No amount previously staked");

        // check withdraw amount
        require(
            withdrawAmount <= plans[1].maxWithdrawal,
            "Maximum 4200 USDT tokens can be withdrawn per day"
        );

        // does plan support withdraw
        require(
            plans[1].capitalReturn == true,
            "You can't unstake your capital in this plan."
        );

        // user can withdraw usdt tokens after 90 days
        uint256 dd = (block.timestamp -
            rookieStakes[msg.sender][id].purchaseTimestamp) / 86400;

        require(dd > plans[1].duration, "Can't unStake before duration.");

        // user total staked amount
        uint256 totalStakedAmount = rookieStakes[msg.sender][id].amount;

        // check if withdraw amount is valid
        require(
            withdrawAmount <= totalStakedAmount,
            "Insufficient withdraw amount"
        );

        // check if 24 hours have passed
        require(
            block.timestamp >
                rookieStakes[msg.sender][id].lastWithdrawalTimestamp +
                    DAY_IN_SECONDS,
            "Cannot withdraw before 24 hours"
        );

        // check how many usdt tokens contract have
        uint256 vendorBalance = USDT.balanceOf(address(this));
        require(
            vendorBalance >= withdrawAmount,
            "Vendor have insufficient USDT tokens"
        );

        bool sent = USDT.transfer(msg.sender, withdrawAmount);
        require(sent, "Failed to transfer USDT token to user");

        rookieStakes[msg.sender][id].withdrawAmount += withdrawAmount;
        rookieStakes[msg.sender][id].lastWithdrawalTimestamp = block.timestamp;

        emit Unstaked(msg.sender, withdrawAmount, 1);
    }

    function proUnStake(uint256 withdrawAmount, uint256 id) public {
        ProPlan storage pStakes = proStakes[msg.sender][id];
        require(pStakes.amount > 0, "No amount previously staked");

        // check withdraw amount
        require(
            withdrawAmount <= plans[2].maxWithdrawal,
            "Maximum 4200 USDT tokens can be withdrawn per day"
        );

        // does plan support withdraw
        require(
            plans[2].capitalReturn == true,
            "You can't unstake your capital in this plan."
        );

        // user can withdraw usdt tokens after 90 days
        uint256 dd = (block.timestamp -
            proStakes[msg.sender][id].purchaseTimestamp) / 86400;

        require(dd > plans[2].duration, "Can't unStake before duration.");

        // user total staked amount
        uint256 totalStakedAmount = proStakes[msg.sender][id].amount;

        // check if withdraw amount is valid
        require(
            withdrawAmount <= totalStakedAmount,
            "Insufficient withdraw amount"
        );

        // check if 24 hours have passed
        require(
            block.timestamp >
                proStakes[msg.sender][id].lastWithdrawalTimestamp +
                    DAY_IN_SECONDS,
            "Cannot withdraw before 24 hours"
        );

        // check how many usdt tokens contract have
        uint256 vendorBalance = USDT.balanceOf(address(this));
        require(
            vendorBalance >= withdrawAmount,
            "Vendor have insufficient USDT tokens"
        );

        bool sent = USDT.transfer(msg.sender, withdrawAmount);
        require(sent, "Failed to transfer USDT token to user");

        proStakes[msg.sender][id].withdrawAmount += withdrawAmount;
        proStakes[msg.sender][id].lastWithdrawalTimestamp = block.timestamp;

        emit Unstaked(msg.sender, withdrawAmount, 1);
    }

    function claimRookieReward(uint256 id) public {
        // total amount staked
        uint256 totalStakedAmount = rookieStakes[msg.sender][id].amount;

        require(
            totalStakedAmount >= plans[1].minAmount,
            "Please Stake the some USDT."
        );

        // check staking has passed duration
        uint256 dd = (block.timestamp -
            rookieStakes[msg.sender][id].purchaseTimestamp) / 86400;

        require(dd > plans[1].duration, "Plan is expired.");

        // calculate reward per day
        uint256 reward = (totalStakedAmount * plans[1].dailyReward) / 10000;
        uint256 rewardAfterFee = reward - (reward / 10);

        uint256 vendorBalance = USDT.balanceOf(address(this));
        require(
            vendorBalance >= rewardAfterFee,
            "Vendor have insufficient USDT tokens"
        );

        bool sent = USDT.transfer(msg.sender, rewardAfterFee);
        require(sent, "Failed to transfer USDT token to user");

        rookieStakes[msg.sender][id].lastClaimedTimestamp = block.timestamp;
        rookieStakes[msg.sender][id].claimedReward =
            rookieStakes[msg.sender][id].claimedReward +
            rewardAfterFee;

        emit RewardClaimed(msg.sender, rewardAfterFee);
    }

    function claimProReward(uint256 id) public {
        uint256 unStakeAmount = proStakes[msg.sender][id].amount;
        require(
            unStakeAmount >= plans[2].minAmount,
            "Please Stake the some USDT."
        );

        uint256 dd = (block.timestamp -
            proStakes[msg.sender][id].purchaseTimestamp) / 86400;
        require(dd < plans[2].duration, "Plan is expired.");

        uint256 reward = (unStakeAmount * plans[2].dailyReward) / 10000;
        uint256 rewardAfterFee = reward - (reward / 10);

        // uint256 vendorBalance = USDT_Token.balanceOf(address(this));
        // require(
        //     vendorBalance >= rewardAfterFee,
        //     "Vendor have insufficient USDT tokens"
        // );

        // bool sent = USDT_Token.transfer(msg.sender, rewardAfterFee);
        // require(sent, "Failed to transfer USDT token to user");

        proStakes[msg.sender][id].claimedReward =
            proStakes[msg.sender][id].claimedReward +
            rewardAfterFee;

        emit RewardClaimed(msg.sender, rewardAfterFee);
    }

    function claimMasterReward(uint256 id) public {
        uint256 unStakeAmount = masterStakes[msg.sender][id].amount;
        require(
            unStakeAmount >= plans[3].minAmount,
            "Please Stake the some USDT."
        );

        uint256 dd = (block.timestamp -
            masterStakes[msg.sender][id].purchaseTimestamp) / 86400;
        require(dd < plans[3].duration, "Plan is expired.");

        uint256 reward = (unStakeAmount * plans[3].dailyReward) / 10000;
        uint256 rewardAfterFee = reward - (reward / 10);

        // uint256 vendorBalance = USDT_Token.balanceOf(address(this));
        // require(
        //     vendorBalance >= rewardAfterFee,
        //     "Vendor have insufficient USDT tokens"
        // );

        // bool sent = USDT_Token.transfer(msg.sender, rewardAfterFee);
        // require(sent, "Failed to transfer USDT token to user");

        masterStakes[msg.sender][id].claimedReward =
            masterStakes[msg.sender][id].claimedReward +
            rewardAfterFee;

        emit RewardClaimed(msg.sender, rewardAfterFee);
    }

    function claimFees() public onlyOwner {
        require(totalFees > 0, "No fees");
        USDT.transfer(address(this), totalFees);
    }
}
