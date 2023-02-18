// SPDX-License-Identifier: MIT

//Deposit Fee Left
pragma solidity ^0.8.4;

import "./USDT.sol";
import "./Private_Garden.sol";

contract StakingPlan {
    USDTToken USDT_Token;
    PrivateGardenToken PVGN_Token;

    // mapping from plan IDs to plan details
    mapping(uint => Plan) public plans;

    uint256 public constant DEPOSIT_Fee_PERCENTAGE = 5; // deposit fee %
    uint256 public constant WITHDRAW_Fee_PERCENTAGE = 10; // withdraw fee %
    uint256 public constant DAY_IN_SECONDS = 24 * 60 * 60; //86400

    uint256 public constant REWARD_PER_TOKEN = 4.2 * 10 ** 18; // 4.2 rewards per token deposited
    uint256 public totalFees; // Total Collected Fees

    // struct representing a plan
    struct Plan {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 duration; // duration of the plan in days
        uint256 dailyReward; // daily reward in reward tokens %
        uint256 monthlyReward; // daily reward in reward tokens
        uint256 totalRoi; // daily reward in reward tokens
        bool capitalReturn; // daily reward in reward tokens
    }

    struct RookiePlan {
        uint256 amount;
        uint256 purchaseTimestamp;
        uint256 lastClaimedRewardTimestamp; // last claimed reward timestamp
        uint256 claimedReward; // daily reward in reward tokens
        uint256 claimedAble; // daily reward in reward tokens
        bool capitalReturned; // capital return
    }

    struct ProPlan {
        uint256 amount;
        uint256 lastClaimedRewardTimestamp; // last claimed reward timestamp
        uint256 purchaseTimestamp;
        uint256 claimedReward; // duration of the plan in days
        uint256 claimedAble; // daily reward in reward tokens
        bool capitalReturned; // daily reward in reward tokens
    }

    struct MasterPlan {
        uint256 amount;
        uint256 lastClaimedRewardTimestamp; // last claimed reward timestamp
        uint256 purchaseTimestamp;
        uint256 claimedAble; // daily reward in reward tokens
        uint256 claimedReward; // duration of the plan in days
        bool capitalReturned; // daily reward in reward tokens
    }

    // Maps addresses to the amount of tokens they have staked
    mapping(address => RookiePlan) public rookieStakes;

    // Maps addresses to the amount of tokens they have staked
    mapping(address => ProPlan) public proStakes;

    // Maps addresses to the amount of tokens they have staked
    mapping(address => MasterPlan) public masterStakes;

    // Events
    event Staked(
        address staker,
        uint256 amount,
        uint256 unlockTimestamp,
        uint256 planId
    );
    event Unstaked(address staker, uint256 amount, uint256 planId);
    event RewardClaimed(address staker, uint256 amount);

    // Constructor
    constructor(address _tokenAddress, address _usdtTokenAddress) {
        USDT_Token = USDTToken(_usdtTokenAddress);
        PVGN_Token = PrivateGardenToken(_tokenAddress);
        plans[1] = Plan(50e6, 25000e6, 90, 40, 120, 36, true); //40 equals to 0.4%
        plans[2] = Plan(1000e6, 25000e6, 180, 46, 140, 84, true);
        plans[3] = Plan(1000e6, 85000e6, 320, 75, 227, 204, false);
    }

    // Stake tokens
    //tokenAmountStake =  100 USDT = 100e6
    function rookieStake(uint256 tokenAmountToStake) public {
        require(
            tokenAmountToStake >= plans[1].minAmount,
            "Specify an amount of token greater than minimum amount of Rookie Plan"
        );

        require(
            tokenAmountToStake <= plans[1].maxAmount,
            "Specify an amount of token less than maximum amount of Rookie Plan"
        );

        require(
            rookieStakes[msg.sender].amount + tokenAmountToStake < 25000e6,
            "Maximum 25000 USDT can be deposited per wallet"
        );

        uint256 userBalance = USDT_Token.balanceOf(msg.sender);

        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        totalFees = totalFees + fee;

        // amount of usdt staked after fee deduction
        uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 claimAbleStakeReward = (stakeAmount *
            plans[1].dailyReward *
            90) / 10000;

        uint256 reward_pvgn = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10 ** (6);
        uint256 vendorBalance = PVGN_Token.balanceOf(address(this));
        require(
            vendorBalance >= reward_pvgn,
            "Vendor have insufficient PVGN tokens"
        );
        bool sent = USDT_Token.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        rookieStakes[msg.sender].amount += stakeAmount;
        rookieStakes[msg.sender].purchaseTimestamp = block.timestamp;
        rookieStakes[msg.sender].lastClaimedRewardTimestamp = block.timestamp;
        rookieStakes[msg.sender].claimedAble += claimAbleStakeReward;
        rookieStakes[msg.sender].capitalReturned = false;

        PVGN_Token.transfer(msg.sender, reward_pvgn);

        emit Staked(
            msg.sender,
            tokenAmountToStake,
            rookieStakes[msg.sender].purchaseTimestamp,
            1
        );
    }

    function claimRookieReward() public {
        uint256 unStakeAmount = rookieStakes[msg.sender].amount;
        require(unStakeAmount >= 40, "Please Stake the some USDT.");

        uint256 rewardInitialDays = (block.timestamp -
            rookieStakes[msg.sender].purchaseTimestamp) / 86400;
        require(
            rewardInitialDays > 2,
            "Claim reward will be start after 48 hours."
        );

        require(
            rookieStakes[msg.sender].claimedReward <=
                rookieStakes[msg.sender].claimedAble,
            "You already claimed your all reward."
        );

        uint256 rewardDays = (block.timestamp -
            rookieStakes[msg.sender].lastClaimedRewardTimestamp) / 86400;
        require(rewardDays > 0, "You already claimed your daily reward.");
        if (rewardDays > 90) rewardDays = 90;

        uint256 reward = rewardDays *
            ((unStakeAmount * plans[1].dailyReward) / 10000);

        if (
            reward + rookieStakes[msg.sender].claimedReward >
            rookieStakes[msg.sender].claimedAble
        ) {
            rookieStakes[msg.sender].claimedAble -
                rookieStakes[msg.sender].claimedReward;
        }

        uint256 rewardAfterFee = reward - (reward / 10);

        uint256 vendorBalance = USDT_Token.balanceOf(address(this));
        require(
            vendorBalance >= rewardAfterFee,
            "Vendor have insufficient USDT tokens"
        );

        bool sent = USDT_Token.transfer(msg.sender, rewardAfterFee);
        require(sent, "Failed to transfer USDT token to user");

        rookieStakes[msg.sender].claimedReward += reward;
        emit RewardClaimed(msg.sender, rewardAfterFee);
    }

    // UnStake tokens
    function rookieUnStake() public {
        require(
            plans[1].capitalReturn == false,
            "You can't unstake your capital in this plan."
        );

        require(
            rookieStakes[msg.sender].capitalReturned == true,
            "You already claimed your capital amount."
        );

        uint256 unStakeAmount = rookieStakes[msg.sender].amount;
        require(unStakeAmount > 40, "Please Stake the amount.");

        uint256 capitalReturnDays = (block.timestamp -
            rookieStakes[msg.sender].purchaseTimestamp) / 86400;
        require(
            capitalReturnDays > plans[1].duration,
            "Can't unStake before duration."
        );

        uint256 vendorBalance = USDT_Token.balanceOf(address(this));
        require(
            vendorBalance >= unStakeAmount,
            "Vendor have insufficient USDT tokens"
        );

        bool sent = USDT_Token.transfer(msg.sender, unStakeAmount);
        require(sent, "Failed to transfer USDT token to user");

        rookieStakes[msg.sender].amount = 0;
        rookieStakes[msg.sender].purchaseTimestamp = 0;
        rookieStakes[msg.sender].lastClaimedRewardTimestamp = 0;
        rookieStakes[msg.sender].claimedReward = 0;
        rookieStakes[msg.sender].claimedAble = 0;
        rookieStakes[msg.sender].capitalReturned = true;

        emit Unstaked(msg.sender, unStakeAmount, 1);
    }

    // Stake tokens
    function proStake(uint256 tokenAmountToStake) public {
        require(
            tokenAmountToStake >= plans[2].minAmount,
            "Specify an amount of token greater than minimum amount of Rookie Plan"
        );

        require(
            tokenAmountToStake <= plans[2].maxAmount,
            "Specify an amount of token less than maximum amount of Rookie Plan"
        );

        require(
            proStakes[msg.sender].amount + tokenAmountToStake < 25000e6,
            "Maximum 25000 USDT can be deposited per wallet"
        );

        uint256 userBalance = USDT_Token.balanceOf(msg.sender);

        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        totalFees = totalFees + fee;

        // amount of usdt staked after fee deduction
        uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 claimAbleStakeReward = (stakeAmount *
            plans[2].dailyReward *
            180) / 10000;

        uint256 reward_pvgn = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10 ** (6);
        uint256 vendorBalance = PVGN_Token.balanceOf(address(this));
        require(
            vendorBalance >= reward_pvgn,
            "Vendor have insufficient PVGN tokens"
        );
        bool sent = USDT_Token.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        proStakes[msg.sender].amount += stakeAmount;
        proStakes[msg.sender].purchaseTimestamp = block.timestamp;
        proStakes[msg.sender].lastClaimedRewardTimestamp = block.timestamp;
        proStakes[msg.sender].claimedAble += claimAbleStakeReward;
        proStakes[msg.sender].capitalReturned = false;

        PVGN_Token.transfer(msg.sender, reward_pvgn);

        emit Staked(
            msg.sender,
            tokenAmountToStake,
            proStakes[msg.sender].purchaseTimestamp,
            2
        );
    }

    function proUnStake() public {
        require(
            plans[2].capitalReturn == false,
            "You can't unstake your capital in this plan."
        );

        require(
            proStakes[msg.sender].capitalReturned == true,
            "You already claimed your capital amount."
        );

        uint256 unStakeAmount = proStakes[msg.sender].amount;
        require(unStakeAmount > 900, "Please Stake the amount.");

        uint256 capitalReturnDays = (block.timestamp -
            proStakes[msg.sender].purchaseTimestamp) / 86400;
        require(
            capitalReturnDays > plans[2].duration,
            "Can't unStake before duration."
        );

        uint256 vendorBalance = USDT_Token.balanceOf(address(this));
        require(
            vendorBalance >= unStakeAmount,
            "Vendor have insufficient USDT tokens"
        );

        bool sent = USDT_Token.transfer(msg.sender, unStakeAmount);
        require(sent, "Failed to transfer USDT token to user");

        proStakes[msg.sender].amount = 0;
        proStakes[msg.sender].purchaseTimestamp = 0;
        proStakes[msg.sender].lastClaimedRewardTimestamp = 0;
        proStakes[msg.sender].claimedReward = 0;
        proStakes[msg.sender].claimedAble = 0;
        proStakes[msg.sender].capitalReturned = true;

        emit Unstaked(msg.sender, unStakeAmount, 1);
    }

    function claimProReward() public {
        uint256 unStakeAmount = proStakes[msg.sender].amount;
        require(unStakeAmount >= 900, "Please Stake the some USDT.");

        uint256 rewardInitialDays = (block.timestamp -
            proStakes[msg.sender].purchaseTimestamp) / 86400;
        require(
            rewardInitialDays > 2,
            "Claim reward will be start after 48 hours."
        );

        require(
            proStakes[msg.sender].claimedReward <=
                proStakes[msg.sender].claimedAble,
            "You already claimed your all reward."
        );

        uint256 rewardDays = (block.timestamp -
            proStakes[msg.sender].lastClaimedRewardTimestamp) / 86400;
        require(rewardDays > 0, "You already claimed your daily reward.");
        if (rewardDays > 180) rewardDays = 180;

        uint256 reward = rewardDays *
            ((unStakeAmount * plans[2].dailyReward) / 10000);

        if (
            reward + proStakes[msg.sender].claimedReward >
            proStakes[msg.sender].claimedAble
        ) {
            proStakes[msg.sender].claimedAble -
                proStakes[msg.sender].claimedReward;
        }

        uint256 rewardAfterFee = reward - (reward / 10);

        uint256 vendorBalance = USDT_Token.balanceOf(address(this));
        require(
            vendorBalance >= rewardAfterFee,
            "Vendor have insufficient USDT tokens"
        );

        bool sent = USDT_Token.transfer(msg.sender, rewardAfterFee);
        require(sent, "Failed to transfer USDT token to user");

        proStakes[msg.sender].claimedReward += reward;
        emit RewardClaimed(msg.sender, reward);
    }

    // Stake tokens
    function masterStake(uint256 tokenAmountToStake) public {
        require(
            tokenAmountToStake >= plans[3].minAmount,
            "Specify an amount of token greater than minimum amount of Rookie Plan"
        );

        require(
            tokenAmountToStake <= plans[3].maxAmount,
            "Specify an amount of token less than maximum amount of Rookie Plan"
        );

        require(
            masterStakes[msg.sender].amount + tokenAmountToStake < 85000e6,
            "Maximum 85000 USDT can be deposited per wallet"
        );

        uint256 userBalance = USDT_Token.balanceOf(msg.sender);

        require(
            userBalance >= tokenAmountToStake,
            "You have insufficient USDT tokens"
        );

        uint256 fee = (tokenAmountToStake * DEPOSIT_Fee_PERCENTAGE) / 100;
        totalFees = totalFees + fee;

        // amount of usdt staked after fee deduction
        uint256 stakeAmount = tokenAmountToStake - fee;
        uint256 claimAbleStakeReward = (stakeAmount *
            plans[3].dailyReward *
            270) / 10000;

        uint256 reward_pvgn = (tokenAmountToStake * REWARD_PER_TOKEN) /
            10 ** (6);
        uint256 vendorBalance = PVGN_Token.balanceOf(address(this));
        require(
            vendorBalance >= reward_pvgn,
            "Vendor have insufficient PVGN tokens"
        );
        bool sent = USDT_Token.transferFrom(
            msg.sender,
            address(this),
            tokenAmountToStake
        );
        require(sent, "Failed to transfer USDT tokens from user to vendor");

        masterStakes[msg.sender].amount += stakeAmount;
        masterStakes[msg.sender].purchaseTimestamp = block.timestamp;
        masterStakes[msg.sender].lastClaimedRewardTimestamp = block.timestamp;
        masterStakes[msg.sender].claimedAble += claimAbleStakeReward;
        masterStakes[msg.sender].capitalReturned = false;

        PVGN_Token.transfer(msg.sender, reward_pvgn);

        emit Staked(
            msg.sender,
            tokenAmountToStake,
            masterStakes[msg.sender].purchaseTimestamp,
            3
        );
    }

    function claimMasterReward() public {
        uint256 unStakeAmount = masterStakes[msg.sender].amount;
        require(unStakeAmount >= 900, "Please Stake the some USDT.");

        uint256 rewardInitialDays = (block.timestamp -
            masterStakes[msg.sender].purchaseTimestamp) / 86400;
        require(
            rewardInitialDays > 2,
            "Claim reward will be start after 48 hours."
        );

        require(
            masterStakes[msg.sender].claimedReward <=
                masterStakes[msg.sender].claimedAble,
            "You already claimed your all reward."
        );

        uint256 rewardDays = (block.timestamp -
            masterStakes[msg.sender].lastClaimedRewardTimestamp) / 86400;
        require(rewardDays > 0, "You already claimed your daily reward.");
        if (rewardDays > 270) rewardDays = 270;

        uint256 reward = rewardDays *
            ((unStakeAmount * plans[3].dailyReward) / 10000);

        if (
            reward + masterStakes[msg.sender].claimedReward >
            masterStakes[msg.sender].claimedAble
        ) {
            masterStakes[msg.sender].claimedAble -
                masterStakes[msg.sender].claimedReward;
        }

        uint256 rewardAfterFee = reward - (reward / 10);

        uint256 vendorBalance = USDT_Token.balanceOf(address(this));
        require(
            vendorBalance >= rewardAfterFee,
            "Vendor have insufficient USDT tokens"
        );

        bool sent = USDT_Token.transfer(msg.sender, rewardAfterFee);
        require(sent, "Failed to transfer USDT token to user");

        masterStakes[msg.sender].claimedReward += reward;
        emit RewardClaimed(msg.sender, reward);
    }

    function claimFeesUSDT(uint256 withdrawUSDT) public onlyOwner {
        uint256 userBalance = USDT_Token.balanceOf(msg.sender);
        require(userBalance >= withdrawUSDT, "No fees");
        USDT_Token.transfer(address(this), withdrawUSDT);
    }

    function claimFeesPVGN(uint256 withdrawPVGN) public onlyOwner {
        uint256 userBalance = PVGN_Token.balanceOf(msg.sender);
        require(userBalance >= withdrawPVGN, "No fees");
        PVGN_Token.transfer(address(this), withdrawPVGN);
    }
}
