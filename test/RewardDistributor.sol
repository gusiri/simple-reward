// SPDX-License-Identifier
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/RewardDistributor.sol";
import "../mock/Token.sol";
import "forge-std/console.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract RewardDistributorTest is Test {
    Vault vault;
    Vault vault2;
    Token token;
    Token rewardToken;
    address alice;
    address bob;
    address charlie;
    address owner;
    address distributor1;
    address distributor2;
    address distributor3;
    address leo;
    address tokenAddress = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; //example GMX Arbitrium token address
    uint256 NUM_USERS = 1000;

    address payable[] internal users;

    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

    function getNextUserAddress() external returns (address payable) {
        //bytes32 to address conversion
        address payable user = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    function createUsers(
        uint256 userNum,
        uint256 initialFunds,
        string[] memory userLabels
    ) public returns (address payable[] memory) {
        address payable[] memory users = new address payable[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            address payable user = this.getNextUserAddress();
            vm.deal(user, initialFunds);
            users[i] = user;

            if (userLabels.length != 0) {
                vm.label(user, userLabels[i]);
            }
        }
        return users;
    }

    function createUsers(uint256 userNum, uint256 initialFunds) public returns (address payable[] memory) {
        string[] memory a;
        return createUsers(userNum, initialFunds, a);
    }

    //create users with 100 ether balance
    function createUsers(uint256 userNum) public returns (address payable[] memory) {
        return createUsers(userNum, 100 ether);
    }

    function setUp() public {
        owner = vm.addr(0xbeef);

        token = new Token("Test token", "TST");
        rewardToken = new Token("Reward token", "RWT");

        vm.startPrank(owner);
        vault = new Vault(address(token), address(rewardToken));
        vault2 = new Vault(address(token), address(rewardToken));
        vm.stopPrank();

        alice = vm.addr(0x01);
        bob = vm.addr(0x02);
        charlie = vm.addr(0xdead);

        distributor1 = vm.addr(0x03);
        distributor2 = vm.addr(0x04);
        distributor3 = vm.addr(0x05);
        
        vm.deal(alice, 10000 ether);
        vm.deal(bob, 10000 ether);
        vm.deal(charlie, 10000 ether);

        rewardToken.mint(address(distributor1), 10000 ether);
        rewardToken.mint(address(distributor2), 10000 ether);
        rewardToken.mint(address(distributor3), 10000 ether);

        token.mint(address(alice), 10000 ether);
        token.mint(address(bob), 1000 ether);
        token.mint(address(charlie), 10000 ether);
        token.mint(address(leo), 500001 ether);

        // setup for testGasEstimationDepositWithManyUsers
        users = createUsers(NUM_USERS);
        for (uint256 i = 0; i < NUM_USERS; i++) {
            token.mint(address(users[i]), 1000 ether);
        }

        for (uint256 i= 0 ; i < NUM_USERS; i++) {
            vm.startPrank(users[i]);
            token.approve(address(vault2), 1000 ether);
            vault2.stake(1000 ether);
            assertEq(vault2.balanceOf(users[i]), 1000 ether);
            vm.stopPrank();
        }
    }

    // stake tokens in vault
    function testStake() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        assertEq(vault.totalSupply(), 1000 ether);
    }

    // expect unstaking to fail because of timelock
    function testFailUnstakeWithLockTimeNotExpired() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        assertEq(token.balanceOf(bob), 9000 ether);

        vault.unstake();
    }

    // expect unstaking to fail because of Insufficient balance
    function testFailUnstakeWithInsufficientBalance() public {
        vm.startPrank(bob);
        vault.unstake();
    }

    // expect staking to fail because of maxStake
    function testFailMaxStake() public {
        vm.startPrank(leo);
        token.approve(address(vault), 500000 ether);
        vault.stake(500000 ether);
        assertEq(vault.balanceOf(leo), 500000 ether);

        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
    }

    // deposit 1 ether into vault
    function testDeposit() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        vm.stopPrank();

        // deposit reward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9000 ether);
        vm.stopPrank();

        assertEq(vault.calculateRewardsEarned(address(bob)), 1000 ether);

        vm.warp(7776010);

        assertEq(vault.calculateRewardsEarned(address(bob)), 1000 ether);

        vm.startPrank(bob);
        uint256 rewards = vault.withdrawReward();
        assertEq(rewards, 1000 ether);
    }

    // deposit tokens with 2 users and check balances
    function testDepositWithTwoUsers() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(alice), 1000 ether);
        vm.stopPrank();

        assertEq(vault.totalSupply(), 2000 ether);

        // deposit reward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9000 ether);
        vm.stopPrank();

        // deposit reward
        vm.startPrank(distributor2);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor2)), 9000 ether);
        vm.stopPrank();

        uint256 vaultBalance = rewardToken.balanceOf(address(vault));
        assertEq(vaultBalance, 2000 ether);

        uint256 rewards = vault.calculateRewardsEarned(address(bob));
        assertEq(rewards, 1000 ether);

        uint256 rewards2 = vault.calculateRewardsEarned(address(alice));
        assertEq(rewards2, 1000 ether);

    }

    function testDistributeRewardAndWithdraw() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        vm.stopPrank();

        // distribute reward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9000 ether);
        vm.stopPrank();

        vm.warp(7776010);

        vm.startPrank(bob);
        vault.unstake();
        assertEq(rewardToken.balanceOf(address(bob)), 1000 ether);
        vm.stopPrank();
    }

    // totalSupply (total # of tokens staked cannot be 0)
    // distributeReward fails when token staked = 0 (divided by 0)
    function testFaildistributeRewardWithZeroTotalSupply() public {

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
    }

    function testFailDistributeRewardWithZeroReward() public {

        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 0 ether);
        vault.distributeReward(0 ether);
    }

    function testMultipledistributeRewardsAndWithdraw() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9000 ether);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor2);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor2)), 9000 ether);
        vm.stopPrank();

        vm.warp(7776010);

        vm.startPrank(bob);
        vault.unstake();
        assertEq(rewardToken.balanceOf(address(bob)), 2000 ether);
        vm.stopPrank();
    }

    function testWithdrawReward() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9000 ether);
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(address(vault)), 1000 ether);

        vm.warp(7776010);

        vm.startPrank(bob);
        vault.withdrawReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(address(bob)), 1000 ether);
        assertEq(rewardToken.balanceOf(address(vault)), 0 ether);
    }

    function testFailWithdrawRewardWithInsufficientReward() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9000 ether);
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(address(vault)), 1000 ether);

        vm.warp(7776010);

        vm.startPrank(bob);
        vault.withdrawReward();
        vault.withdrawReward(); // insufficient reward
        vm.stopPrank();
    }

    function testMultilpleRewardsAndWithdrawReward() public {
        vm.startPrank(bob);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);
        assertEq(vault.balanceOf(bob), 1000 ether);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 10000 ether);
        vault.distributeReward(10000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 0 ether);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor2);
        rewardToken.approve(address(vault), 1 ether);
        vault.distributeReward(1 ether);
        assertEq(rewardToken.balanceOf(address(distributor2)), 9999 ether);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor3);
        rewardToken.approve(address(vault), 0.5 ether);
        vault.distributeReward(0.5 ether);
        assertEq(rewardToken.balanceOf(address(distributor3)), 9999.5 ether);
        vm.stopPrank();

        vm.warp(7776010);

        vm.startPrank(bob);
        vault.withdrawReward();
        assertEq(rewardToken.balanceOf(address(bob)), 10001.5 ether);
    }


    function testDistributeRewardTokensWithdrawOddAmounts() public {
        vm.startPrank(bob);
        uint256 amount = 1000 ether;
        token.approve(address(vault), amount);
        vault.stake(amount);
        assertEq(vault.balanceOf(bob), amount);
        vm.stopPrank();

        vm.startPrank(alice);
        amount = 2000 ether;
        token.approve(address(vault), amount);
        vault.stake(amount);
        assertEq(vault.balanceOf(alice), amount);
        vm.stopPrank();

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1 ether);
        vault.distributeReward(1 ether);
        rewardToken.approve(address(vault), 1 ether);
        vault.distributeReward(1 ether);
        rewardToken.approve(address(vault), 1 ether);
        vault.distributeReward(1 ether);
        rewardToken.approve(address(vault), 1 ether);
        vault.distributeReward(1 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9996 ether);
        assertEq(rewardToken.balanceOf(address(vault)), 4 ether);
        vm.stopPrank();

        vm.warp(7776010);

        vm.startPrank(alice);
        vault.unstake();
        //console.log("balance", alice.balance);
        assertEq(rewardToken.balanceOf(address(alice)), 2666666666666664000);
        vm.stopPrank();

    }

    function testFailMultipleStakeWithLockTime() public {
        vm.startPrank(alice);
        token.approve(address(vault), 1000 ether);
        vault.stake(1000 ether);

        assertEq(vault.balanceOf(alice), 1000 ether);
        assertEq(alice.balance, 9000 ether);
        vm.stopPrank();


        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), 1000 ether);
        vault.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9000 ether);
        assertEq(rewardToken.balanceOf(address(vault)), 1000 ether);
        vm.stopPrank();


        vm.warp(7776010);
        //vault.unstake(); is possible here

        vm.startPrank(alice);
        token.approve(address(vault), 1000 ether);
        // one more stake will reset lockTime
        vault.stake(1000 ether);

        // fail because of the lockTime reset after the stake above
        vault.unstake();

        vm.stopPrank();
    }

    // gas estimation of distributeReward() with many users (See setUp())
    function testGasEstimationWithManyUsers() public {

        // total balance
        assertEq(vault2.totalSupply(), NUM_USERS*1000 ether);

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault2), 1000 ether);
        vault2.distributeReward(1000 ether);
        assertEq(rewardToken.balanceOf(address(distributor1)), 9000 ether);
        vm.stopPrank();

        // reward per user
        //expectedRewards = 1000 / NUM_USERS ether
        vm.startPrank(users[0]);
        assertEq(vault2.calculateRewardsEarned(address(users[0])), 1 ether);
        vm.warp(7776010);

        vault2.unstake();

        assertEq(rewardToken.balanceOf(address(users[0])), 1 ether);
        vm.stopPrank();


    }

    // fuzzy testing with 1 user
    function testFuzzyDistributeRewardAndWithdraw(uint256 stakeAmount, uint256 distributeAmount) public {

        // bound input
        stakeAmount = bound(stakeAmount, 1000 ether, 500_000 ether); // minStake and maxStake
        distributeAmount = bound(distributeAmount, 1, 10_000 ether); // minStake and maxStake

        vm.startPrank(leo);
        token.approve(address(vault), stakeAmount);
        vault.stake(stakeAmount);
        assertEq(vault.balanceOf(leo), stakeAmount);
        vm.stopPrank();

        assertEq(vault.totalSupply(), stakeAmount);

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), distributeAmount);
        vault.distributeReward(distributeAmount);
        vm.stopPrank();

        uint256 totalSupply = token.balanceOf(address(vault));
        assertEq(totalSupply, stakeAmount);

        uint256 vaultBalance = rewardToken.balanceOf(address(vault));
        assertEq(vaultBalance, distributeAmount);

        uint256 rewards = vault.calculateRewardsEarned(address(leo));
        assertLe(distributeAmount-rewards, 0.000000000001 ether);
        // Ideally with 1 user, the reward should be equal to the amount distributed
        // However, it can be slightly smaller than the amount distributed because of some ROUNDDOWNs in distributeReward()
        // Looked into the fuzzy testcases and the difference is not larger than 0.000000000001 ether even in the worst case

    }

    // fuzzy testing - distributeReward tokens with 2 users and check balances
    function testFuzzyDistributeRewardWithTwoUsers(uint256 amountBob, uint256 amountAlice, uint256 distributeAmount) public {
        token.mint(address(alice), 500_000 ether);
        token.mint(address(bob), 500_000 ether);

        // bound input
        amountBob = bound(amountBob, 1000 ether, 500_000 ether);
        amountAlice = bound(amountAlice, 1000 ether, 500_000 ether);
        distributeAmount = bound(distributeAmount, 1, 10000 ether);

        vm.startPrank(bob);
        token.approve(address(vault), amountBob);
        vault.stake(amountBob);
        assertEq(vault.balanceOf(bob), amountBob);
        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(vault), amountAlice);
        vault.stake(amountAlice);
        assertEq(vault.balanceOf(alice), amountAlice);
        vm.stopPrank();

        assertEq(vault.totalSupply(), amountBob+amountAlice);

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), distributeAmount);
        vault.distributeReward(distributeAmount);
        vm.stopPrank();

        uint256 vaultBalance = rewardToken.balanceOf(address(vault));
        assertEq(vaultBalance, distributeAmount);

        uint256 rewardBob = vault.calculateRewardsEarned(address(bob));
        uint256 expectedRewardBob = distributeAmount * amountBob/(amountBob+amountAlice);
        assertLe(expectedRewardBob-rewardBob, 0.000000000001 ether);

        uint256 rewardAlice = vault.calculateRewardsEarned(address(alice));
        uint256 expectedRewardAlice = distributeAmount * amountAlice/(amountBob+amountAlice);
        assertLe(expectedRewardAlice-rewardAlice, 0.000000000001 ether);
    }

    function testFuzzyMultipleDistributeRewards(uint256 amountBob, uint256 amountAlice, uint256 distributeAmount1, uint256 distributeAmount2) public {
        token.mint(address(alice), 500_000 ether);
        token.mint(address(bob), 500_000 ether);

        // bound input
        amountBob = bound(amountBob, 1000 ether, 500_000 ether);
        amountAlice = bound(amountAlice, 1000 ether, 500_000 ether);
        distributeAmount1 = bound(distributeAmount1, 1, 4999 ether);
        distributeAmount2 = bound(distributeAmount2, 1, 4999 ether);

        vm.startPrank(bob);
        token.approve(address(vault), amountBob);
        vault.stake(amountBob);
        assertEq(vault.balanceOf(bob), amountBob);
        vm.stopPrank();

        // alice stake
        vm.startPrank(alice);
        token.approve(address(vault), amountAlice);
        vault.stake(amountAlice);
        assertEq(vault.balanceOf(alice), amountAlice);
        vm.stopPrank();

        assertEq(vault.totalSupply(), amountBob+amountAlice);

        // distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), distributeAmount1);
        vault.distributeReward(distributeAmount1);

        rewardToken.approve(address(vault), distributeAmount2);
        vault.distributeReward(distributeAmount2);
        vm.stopPrank();


        uint256 vaultBalance = rewardToken.balanceOf(address(vault));
        assertEq(vaultBalance, distributeAmount1+distributeAmount2);

        uint256 rewardBob = vault.calculateRewardsEarned(address(bob));
        uint256 expectedRewardBob = (distributeAmount1+distributeAmount2)* amountBob/(amountBob+amountAlice);
        assertLe(expectedRewardBob-rewardBob, 0.000000000001 ether);

        uint256 rewardAlice = vault.calculateRewardsEarned(address(alice));
        uint256 expectedRewardAlice = (distributeAmount1+distributeAmount2) * amountAlice/(amountBob+amountAlice);
        assertLe(expectedRewardAlice-rewardAlice, 0.000000000001 ether);
    }

    function testFuzzyMultipleStakingAndMultipleDistributeRewards(uint256 amountBob, uint256 amountBob2, uint256 amountAlice, uint256 amountAlice2, uint256 distributeAmount1, uint256 distributeAmount2) public {
        token.mint(address(alice), 500_000 ether);
        token.mint(address(bob), 500_000 ether);

        // bound input
        amountBob = bound(amountBob, 1000 ether, 249_999 ether);
        amountBob2 = bound(amountBob2, 1000 ether, 249_999 ether);
        amountAlice = bound(amountAlice, 1000 ether, 249_999 ether);
        amountAlice2 = bound(amountAlice2, 1000 ether, 249_999 ether);
        distributeAmount1 = bound(distributeAmount1, 1, 4999 ether);
        distributeAmount2 = bound(distributeAmount2, 1, 4999 ether);

        // staking
        vm.startPrank(bob);
        token.approve(address(vault), amountBob);
        vault.stake(amountBob);
        assertEq(vault.balanceOf(bob), amountBob);
        vm.stopPrank();

        assertEq(vault.totalSupply(), amountBob);

        // first distribute reward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), distributeAmount1);
        vault.distributeReward(distributeAmount1);
        vm.stopPrank();

        uint256 rewardBob = vault.calculateRewardsEarned(address(bob));
        assertLe(distributeAmount1-rewardBob, 0.000000000001 ether);

        // staking
        vm.startPrank(bob);
        token.approve(address(vault), amountBob2);
        vault.stake(amountBob2);
        assertEq(vault.balanceOf(bob), amountBob + amountBob2);
        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(vault), amountAlice);
        vault.stake(amountAlice);
        assertEq(vault.balanceOf(alice), amountAlice);
        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(vault), amountAlice2);
        vault.stake(amountAlice2);
        assertEq(vault.balanceOf(alice), amountAlice + amountAlice2);
        vm.stopPrank();

        assertEq(vault.totalSupply(), amountBob+amountBob2+amountAlice+amountAlice2);

        // second distributeReward
        vm.startPrank(distributor1);
        rewardToken.approve(address(vault), distributeAmount2);
        vault.distributeReward(distributeAmount2);
        vm.stopPrank();

        uint256 vaultBalance = rewardToken.balanceOf(address(vault));
        assertEq(vaultBalance, distributeAmount1+distributeAmount2);

        uint256 totalSupply = vault.totalSupply();

        uint256 rewardBob2 = vault.calculateRewardsEarned(address(bob));
        uint256 expectedRewardBob = rewardBob + ( distributeAmount2 * (amountBob+amountBob2) / totalSupply );
        assertLe(expectedRewardBob-rewardBob2, 0.000000000001 ether);

        uint256 rewardAlice = vault.calculateRewardsEarned(address(alice));
        uint256 expectedRewardAlice = distributeAmount2 * (amountAlice+amountAlice2) / totalSupply;
        assertLe(expectedRewardAlice-rewardAlice, 0.000000000001 ether);
    }

    function testUpdateDefaultLockTime() public {
        vm.startPrank(owner);
        assertEq(vault.defaultLockTime(), 90 days);
        vault.updateDefaultLockTime(9 days);
        assertEq(vault.defaultLockTime(), 9 days);
    }

    function testFailUpdateDefaultLockTimeWithInvalidInput() public {
        vm.startPrank(owner);
        assertEq(vault.defaultLockTime(), 90 days);
        vault.updateDefaultLockTime(0);
    }

    function testFailUpdateDefaultLockTimeUnauthorized() public {
        vm.startPrank(alice);
        assertEq(vault.defaultLockTime(), 90 days);
        vault.updateDefaultLockTime(9 days);
        assertEq(vault.defaultLockTime(), 9 days);
    }

    function testPause() public {
        vm.startPrank(owner);
        assertEq(vault.paused(), false);
        vault.pause();
        assertEq(vault.paused(), true);
    }

    function testFailPauseUnauthorized() public {
        vm.startPrank(alice);
        assertEq(vault.paused(), false);
        vault.pause();
    }

    function testUnpause() public {
        vm.startPrank(owner);
        assertEq(vault.paused(), false);
        vault.pause();
        assertEq(vault.paused(), true);

        vault.unpause();
        assertEq(vault.paused(), false);
    }

    function testFailUnpauseUnauthorized() public {
        vm.startPrank(owner);
        assertEq(vault.paused(), false);
        vault.pause();
        assertEq(vault.paused(), true);
        vm.stopPrank();

        vm.startPrank(alice);
        vault.unpause();
    }

    function testStakeToken() public {
        vm.startPrank(alice);
        ERC20 tempToken = vault.stakeToken();
        assertEq(tempToken.symbol(), "TST");
    }

    function testRewardToken() public {
        vm.startPrank(alice);
        ERC20 tempToken = vault.rewardToken();
        assertEq(tempToken.symbol(), "RWT");
    }
}