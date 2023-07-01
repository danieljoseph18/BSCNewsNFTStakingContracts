// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployNFTStaking} from "../script/DeployNFTStaking.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {BSCNewsNFTStaking} from "../src/BSCNewsNFTStaking.sol";
import {MockNft} from "../src/mocks/MockNft.sol";
import {MockToken} from "../src/mocks/MockToken.sol";

contract NFTStakingTest is Test {
    BSCNewsNFTStaking public staking;
    HelperConfig public config;

    address nftCollection;
    address rewardToken;
    uint256 startingOwnerBalance = 1e27;
    uint256 randomInterval = 1 days;

    address public OWNER;
    address public USER = makeAddr("user");
    address public ANOTHER_USER = makeAddr("anotherUser");
    uint256 public constant STARTING_USER_BALANCE_ETH = 10 ether;
    uint256 public constant STAKING_AMOUNT = 1e18;
    uint256 public constant STAKING_PERIOD = 365 days;

    modifier startStakingPeriod() {
        vm.startPrank(OWNER);
        MockToken(rewardToken).transfer(address(staking), STAKING_AMOUNT);
        staking.startStakingPeriod(STAKING_AMOUNT, STAKING_PERIOD);
        vm.stopPrank();
        _;
    }

    modifier startStakingPeriodAndMintNFT() {
        vm.startPrank(OWNER);
        MockToken(rewardToken).transfer(address(staking), STAKING_AMOUNT);
        staking.startStakingPeriod(STAKING_AMOUNT, STAKING_PERIOD);
        MockNft(nftCollection).safeMint(USER);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        DeployNFTStaking deploy = new DeployNFTStaking();
        (staking, config) = deploy.run();
        (nftCollection, rewardToken,) = config.config();
        OWNER = MockToken(rewardToken).owner();
        vm.deal(OWNER, STARTING_USER_BALANCE_ETH);
    }

    // Remember to mint NFTs, send tokens to the staking contract etc.
    function testNonOwnersCantStartAStakingPeriod() public {
        vm.startPrank(USER);
        vm.expectRevert();
        staking.startStakingPeriod(STAKING_AMOUNT, STAKING_PERIOD);
        vm.stopPrank();
    }

    function testOwnerCanStartAStakingPeriod() public startStakingPeriod {
        assertEq(MockToken(rewardToken).balanceOf(OWNER), startingOwnerBalance - STAKING_AMOUNT);
        assertEq(staking.periodFinish(), block.timestamp + STAKING_PERIOD);
    }

    function testUserCanStakeIfStakingPeriodLive() public startStakingPeriodAndMintNFT {
        // Make sure user has NFTs to stake
        assertEq(MockNft(nftCollection).balanceOf(USER), 1);
        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        staking.stake(tokensToStake);
        vm.stopPrank();
        // Check the stake was successful
        assertEq(MockNft(nftCollection).balanceOf(USER), 0);
        assertEq(MockNft(nftCollection).balanceOf(address(staking)), 1);
        assertEq(staking.stakedAssets(0), USER);
    }

    function testUserCantStakeIfStakingPeriodIsntLive() public {
        vm.startPrank(OWNER);
        MockNft(nftCollection).safeMint(USER);
        vm.stopPrank();

        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        vm.expectRevert();
        staking.stake(tokensToStake);
        vm.stopPrank();
    }

    // Check user can unstake staked tokens
    function testUserCanUnstakeStakedTokens() public startStakingPeriodAndMintNFT {
        // Stake tokens
        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        staking.stake(tokensToStake);
        vm.stopPrank();
        uint256 stakedSupplyBefore = staking.totalStakedSupply();
        // Unstake tokens
        vm.warp(block.timestamp + randomInterval);
        vm.roll(block.number + 1);

        vm.startPrank(USER);
        staking.withdraw(tokensToStake);
        vm.stopPrank();
        uint256 stakedSupplyAfter = staking.totalStakedSupply();
        assertEq(stakedSupplyAfter, stakedSupplyBefore - 1);
    }

    function testUserCanUnstakeAllStakedTokens() public startStakingPeriod {
        // Start staking period
        vm.startPrank(OWNER);
        MockNft(nftCollection).safeMint(USER);
        MockNft(nftCollection).safeMint(USER);
        MockNft(nftCollection).safeMint(USER);
        vm.stopPrank();
        // Stake multiple tokens
        vm.startPrank(USER);
        MockNft(nftCollection).setApprovalForAll(address(staking), true);
        uint256[] memory tokensToStake = new uint256[](3);
        tokensToStake[0] = 0;
        tokensToStake[1] = 1;
        tokensToStake[2] = 2;
        staking.stake(tokensToStake);
        vm.stopPrank();
        uint256 stakedSupplyBefore = staking.totalStakedSupply();
        // Unstake all tokens in one transaction
        vm.warp(block.timestamp + randomInterval);
        vm.roll(block.number + 1);

        vm.startPrank(USER);
        staking.withdrawAll();
        vm.stopPrank();
        uint256 stakedSupplyAfter = staking.totalStakedSupply();
        assertEq(stakedSupplyAfter, stakedSupplyBefore - 3);
    }

    function testUserCantUnstakeTokensThatDontBelongToThem() public startStakingPeriodAndMintNFT {
        // Stake tokens
        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        staking.stake(tokensToStake);
        vm.stopPrank();

        // Unstake tokens as a different user
        vm.startPrank(ANOTHER_USER);
        vm.expectRevert();
        staking.withdraw(tokensToStake);
        vm.stopPrank();
    }
    // Check user can claim rewards for staked token(s)

    function testUserCantClaimRewardsForTokensThatDontBelongToThem() public startStakingPeriodAndMintNFT {
        // Stake tokens
        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        staking.stake(tokensToStake);
        vm.stopPrank();

        // Claim rewards as a different user
        vm.startPrank(ANOTHER_USER);
        vm.expectRevert();
        staking.claimRewards();
        vm.stopPrank();
    }

    function testUserCanClaimRewardsForStakedTokens() public startStakingPeriodAndMintNFT {
        // Stake tokens
        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        staking.stake(tokensToStake);
        vm.stopPrank();

        // Advance time to allow for rewards
        vm.warp(block.timestamp + randomInterval);
        vm.roll(block.number + 1);

        // Check rewards are above 0
        assertGt(staking.userStakeRewards(USER), 0);
        // Claim rewards
        vm.startPrank(USER);
        staking.claimRewards();
        vm.stopPrank();
        // Check rewards are 0
        assertEq(staking.userStakeRewards(USER), 0);
    }

    // Check user reward calculations are accurate
    function testRewardCalculationsAreAccurate() public startStakingPeriodAndMintNFT {
        // Start staking period
        // Stake tokens
        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        staking.stake(tokensToStake);
        vm.stopPrank();
        // Advance time to allow for rewards
        vm.warp(block.timestamp + randomInterval);
        vm.roll(block.number + 1);
        // Calculate the expected rewards
        // AccumulatedRewards = StakedTokens * (RewardPerToken - UserRewardPerTokenPaid) / 1e18 + Rewards[user]
        uint256 numTokens = staking.userStakedTokens(USER).length;
        uint256 expectedRewards = (numTokens * (staking.getRewardPerToken() - staking.userRewardPerTokenPaid(USER)))
            / 1e18 + staking.userStakeRewards(USER);
        // Compare the expected rewards to actual rewards
        assertEq(staking.calculateRewards(USER), expectedRewards);
    }

    // Check a user can stake after the first staking period ends and the second begins
    function testUserCanStakeTokenAfterTheFirstPeriodEndsAndSecondBegins() public startStakingPeriodAndMintNFT {
        // Advance time to the end of the first staking period
        vm.warp(block.timestamp + STAKING_PERIOD + randomInterval);
        vm.roll(block.number + 1);

        // Start the second staking period
        vm.startPrank(OWNER);
        MockToken(rewardToken).transfer(address(staking), STAKING_AMOUNT);
        staking.startStakingPeriod(STAKING_AMOUNT, STAKING_PERIOD);
        vm.stopPrank();

        // Stake tokens in the second staking period
        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        staking.stake(tokensToStake);
        vm.stopPrank();

        // Check the stake was successful
        assertEq(MockNft(nftCollection).balanceOf(USER), 0);
        assertEq(MockNft(nftCollection).balanceOf(address(staking)), 1);
        assertEq(staking.stakedAssets(0), USER);
    }

    // Check a user cant stake after the first staking period ends
    function testUserCantStakeAfterTheFirstPeriodEnds() public startStakingPeriodAndMintNFT {
        // Advance time to the end of the first staking period
        vm.warp(block.timestamp + STAKING_PERIOD + randomInterval);
        vm.roll(block.number + 1);

        // Try to stake tokens after the first staking period ends
        vm.startPrank(USER);
        MockNft(nftCollection).approve(address(staking), 0);
        uint256[] memory tokensToStake = new uint256[](1);
        tokensToStake[0] = 0;
        vm.expectRevert();
        staking.stake(tokensToStake);
        vm.stopPrank();
    }
}
