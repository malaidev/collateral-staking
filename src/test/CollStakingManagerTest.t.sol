// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.13;

import { BaseTest, console } from "./base/BaseTest.t.sol";
import "../main/CollStakingManager.sol";

import "./mocks/MockERC20.sol";
import "./mocks/MockDpxStakingRewards.sol";
import "./mocks/MockGmxRewardRouterV2.sol";

contract TradeManagerTest is BaseTest {
	bytes private constant REVERT_ZERO_AMOUNT =
		abi.encodeWithSignature("ZeroAmountPassed()");
	bytes private constant REVERT_ZERO_ADDRESS =
		abi.encodeWithSignature("ZeroAddressPassed()");
	bytes private constant REVERT_INSUFFICIENT_CLAIMABLE_AMOUNT =
		abi.encodeWithSignature("InsufficientClaimableAmount()");
	bytes private constant REVERT_INSUFFICIENT_BALANCE =
		abi.encodeWithSignature("InsufficientBalance()");
	string private constant REVERT_CALLER_NOT_WHITELISTED =
		"CallerIsNotWhitelisted(address)";
	string private constant REVERT_NOT_SUPPORTED_ASSET =
		"NotSupportedAsset(address)";
	string private constant REVERT_UNEXPECTED_ETH_RECEIVED =
		"UnexpectedEthReceived(address)";

	address private constant ZERO_ADDRESS = address(0);

	CollStakingManager private underTest;
	MockDpxStakingRewards mockDpxStakingRewards;
	MockGmxRewardRouterV2 mockGmxRewardRouterV2;
	MockERC20 dpxToken;
	MockERC20 gmxToken;

	address dpxTokenAddress;
	address gmxTokenAddress;

	address private owner;
	address private staker;
	address private treasury;
	address private user;

	function setUp() public {
		vm.warp(10000);

		underTest = new CollStakingManager();

		owner = accountsDb.PUBLIC_KEYS(0);
		staker = accountsDb.PUBLIC_KEYS(1);
		treasury = accountsDb.PUBLIC_KEYS(2);
		user = accountsDb.PUBLIC_KEYS(3);

		dpxToken = new MockERC20("Test DPX", "TDPX");
		gmxToken = new MockERC20("Test GMX", "TGMX");

		dpxTokenAddress = address(dpxToken);
		gmxTokenAddress = address(gmxToken);

		uint256 EnoughBigAmount = 1000000000 ether;

		dpxToken.mint(staker, EnoughBigAmount);
		dpxToken.mint(user, EnoughBigAmount);

		gmxToken.mint(staker, EnoughBigAmount);
		gmxToken.mint(user, EnoughBigAmount);

		mockDpxStakingRewards = new MockDpxStakingRewards(dpxTokenAddress);
		mockDpxStakingRewards.setWhitelistedContracts(
			address(underTest),
			true
		);
		dpxToken.mint(address(mockDpxStakingRewards), EnoughBigAmount);

		mockGmxRewardRouterV2 = new MockGmxRewardRouterV2(gmxTokenAddress);
		vm.deal(address(mockGmxRewardRouterV2), EnoughBigAmount);

		vm.startPrank(staker);
		{
			dpxToken.approve(address(underTest), type(uint256).max);
			gmxToken.approve(address(underTest), type(uint256).max);
		}
		vm.stopPrank();

		vm.startPrank(owner);
		{
			underTest.setUp(
				treasury,
				dpxTokenAddress,
				gmxTokenAddress,
				address(mockDpxStakingRewards),
				address(mockGmxRewardRouterV2)
			);
			underTest.setWhitelistAddress(staker, true);
		}
		vm.stopPrank();
	}

	function test_setUp_CallerIsOwner() public prankAs(user) {
		underTest = new CollStakingManager();

		underTest.setUp(
			treasury,
			dpxTokenAddress,
			gmxTokenAddress,
			address(mockDpxStakingRewards),
			address(mockGmxRewardRouterV2)
		);
		assertEq(underTest.owner(), user);
	}

	function test_setUp_asOwner_givenZeroAddresses_thenReverts()
		public
		prankAs(owner)
	{
		underTest = new CollStakingManager();

		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setUp(
			ZERO_ADDRESS,
			dpxTokenAddress,
			gmxTokenAddress,
			address(mockDpxStakingRewards),
			address(mockGmxRewardRouterV2)
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setUp(
			treasury,
			ZERO_ADDRESS,
			gmxTokenAddress,
			address(mockDpxStakingRewards),
			address(mockGmxRewardRouterV2)
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setUp(
			treasury,
			dpxTokenAddress,
			ZERO_ADDRESS,
			address(mockDpxStakingRewards),
			address(mockGmxRewardRouterV2)
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setUp(
			treasury,
			dpxTokenAddress,
			gmxTokenAddress,
			ZERO_ADDRESS,
			address(mockGmxRewardRouterV2)
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setUp(
			treasury,
			dpxTokenAddress,
			gmxTokenAddress,
			address(mockDpxStakingRewards),
			ZERO_ADDRESS
		);
	}

	function test_setUp_asOwner_givenValidAddresses_thenSetValuesCorrectly()
		public
		prankAs(owner)
	{
		underTest = new CollStakingManager();

		underTest.setUp(
			treasury,
			dpxTokenAddress,
			gmxTokenAddress,
			address(mockDpxStakingRewards),
			address(mockGmxRewardRouterV2)
		);
		assertEq(underTest.treasuryAddress(), treasury);
		assertEq(underTest.dpxToken(), dpxTokenAddress);
		assertEq(underTest.gmxToken(), gmxTokenAddress);
		assertEq(
			address(underTest.dpxStakingRewards()),
			address(mockDpxStakingRewards)
		);
		assertEq(
			address(underTest.gmxRewardRouterV2()),
			address(mockGmxRewardRouterV2)
		);
	}

	function test_setTreasuryAddress_asUser_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(NOT_OWNER);
		underTest.setTreasuryAddress(treasury);
	}

	function test_setTreasuryAddress_asOwner_givenZeroAddress_thenReverts()
		public
		prankAs(owner)
	{
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setTreasuryAddress(ZERO_ADDRESS);
	}

	function test_setTreasuryAddress_asOwner_givenValidAddress_thenSetsCorrectly()
		public
		prankAs(owner)
	{
		underTest.setTreasuryAddress(treasury);
		assertEq(underTest.treasuryAddress(), treasury);
	}

	function test_setWhitelistAddress_asUser_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(NOT_OWNER);
		underTest.setWhitelistAddress(staker, true);
	}

	function test_setWhitelistAddress_asOwner_givenZeroAddress_thenReverts()
		public
		prankAs(owner)
	{
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setWhitelistAddress(ZERO_ADDRESS, true);
	}

	function test_setWhitelistAddress_asOwner_givenValidAddress_thenSetsCorrectly()
		public
		prankAs(owner)
	{
		underTest.setWhitelistAddress(staker, true);
		assertTrue(underTest.whitelisted(staker));
		assertTrue(!underTest.whitelisted(user));

		underTest.setWhitelistAddress(staker, false);
		assertTrue(!underTest.whitelisted(staker));
	}

	function test_stakeCollaterals_asUser_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(
			abi.encodeWithSignature(REVERT_CALLER_NOT_WHITELISTED, user)
		);
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
	}

	function test_stakeCollaterals_asStaker_givenUnsupportedAsset_thenReverts()
		public
		prankAs(staker)
	{
		vm.expectRevert(
			abi.encodeWithSignature(REVERT_NOT_SUPPORTED_ASSET, user)
		);
		underTest.stakeCollaterals(user, 1 ether);
	}

	function test_stakeCollaterals_asStaker_givenZeroAmount_thenReverts()
		public
		prankAs(staker)
	{
		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.stakeCollaterals(dpxTokenAddress, 0 ether);
	}

	function test_stakeCollaterals_asStaker_givenDpxStakingAndWhitelisted_thenTopUpDpxBalance()
		public
		prankAs(staker)
	{
		vm.mockCall(
			address(mockDpxStakingRewards),
			abi.encodeWithSignature("earned(address)", address(underTest)),
			abi.encode(0, 0)
		);

		uint256 mockStaking_dpxBalanceBefore = dpxToken.balanceOf(
			address(mockDpxStakingRewards)
		);
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		uint256 mockStaking_dpxBalanceAfter = dpxToken.balanceOf(
			address(mockDpxStakingRewards)
		);

		assertEq(
			mockStaking_dpxBalanceAfter - mockStaking_dpxBalanceBefore,
			1 ether
		);

		assertEq(mockDpxStakingRewards.balanceOf(address(underTest)), 1 ether);
	}

	function test_stakeCollaterals_asStaker_givenDpxStakingAndWhitelisted_thenCompoundsPendingRewards()
		public
		prankAs(staker)
	{
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);

		assertEq(
			mockDpxStakingRewards.balanceOf(address(underTest)),
			1.1 ether
		);
	}

	function test_stakeCollaterals_asStaker_givenDpxStakingAndNotWhitelisted_thenKeepsDpxCollateral()
		public
		prankAs(staker)
	{
		mockDpxStakingRewards.setWhitelistedContracts(
			address(underTest),
			false
		);
		uint256 underTest_dpxBalanceBefore = dpxToken.balanceOf(
			address(underTest)
		);
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		uint256 underTest_dpxBalanceAfter = dpxToken.balanceOf(
			address(underTest)
		);

		assertEq(
			underTest_dpxBalanceAfter - underTest_dpxBalanceBefore,
			1 ether
		);

		assertEq(mockDpxStakingRewards.balanceOf(address(underTest)), 0 ether);
	}

	function test_stakeCollaterals_asStaker_givenGmxStaking_thenTopUpGmxBalance()
		public
		prankAs(staker)
	{
		uint256 mockStaking_gmxBalanceBefore = gmxToken.balanceOf(
			address(mockGmxRewardRouterV2)
		);
		underTest.stakeCollaterals(gmxTokenAddress, 1 ether);
		uint256 mockStaking_gmxBalanceAfter = gmxToken.balanceOf(
			address(mockGmxRewardRouterV2)
		);

		assertEq(
			mockStaking_gmxBalanceAfter - mockStaking_gmxBalanceBefore,
			1 ether
		);
	}

	function test_stakeCollaterals_asStaker_givenGmxStakingWithPendingEthRewards_thenReceivesPendingEthRewards()
		public
		prankAs(staker)
	{
		uint256 mockStaking_ethBalanceBefore = address(underTest).balance;
		underTest.stakeCollaterals(gmxTokenAddress, 1 ether);
		uint256 mockStaking_ethBalanceAfter = address(underTest).balance;

		assertEq(
			mockStaking_ethBalanceAfter - mockStaking_ethBalanceBefore,
			0.1 ether
		);
	}

	function test_unstakeCollaterals_asStaker_givenUnsupportedAsset_thenReverts()
		public
		prankAs(staker)
	{
		vm.expectRevert(
			abi.encodeWithSignature(REVERT_NOT_SUPPORTED_ASSET, user)
		);
		underTest.unstakeCollaterals(user, 1 ether);
	}

	function test_unstakeCollaterals_asStaker_givenZeroAmount_thenReverts()
		public
		prankAs(staker)
	{
		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.unstakeCollaterals(dpxTokenAddress, 0 ether);
	}

	function test_unstakeCollaterals_asStaker_givenLargerAmountThanStaked_thenReverts()
		public
		prankAs(staker)
	{
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		vm.expectRevert(REVERT_INSUFFICIENT_BALANCE);
		underTest.unstakeCollaterals(dpxTokenAddress, 2 ether);

		underTest.stakeCollaterals(gmxTokenAddress, 1 ether);
		vm.expectRevert(REVERT_INSUFFICIENT_BALANCE);
		underTest.unstakeCollaterals(gmxTokenAddress, 2 ether);
	}

	function test_unstakeCollaterals_asStaker_givenDpxValidAmount_thenRefundsDpxToStaker()
		public
		prankAs(staker)
	{
		vm.mockCall(
			address(mockDpxStakingRewards),
			abi.encodeWithSignature("earned(address)", address(underTest)),
			abi.encode(0, 0)
		);

		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		uint256 staker_dpxBalanceBefore = dpxToken.balanceOf(address(staker));
		underTest.unstakeCollaterals(dpxTokenAddress, 1 ether);
		uint256 staker_dpxBalanceAfter = dpxToken.balanceOf(address(staker));

		assertEq(staker_dpxBalanceAfter - staker_dpxBalanceBefore, 1 ether);

		assertEq(mockDpxStakingRewards.balanceOf(address(underTest)), 0 ether);
	}

	function test_unstakeCollaterals_asStaker_givenDpxValidAmount_thenCompoundsPendingRewards()
		public
		prankAs(staker)
	{
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		underTest.unstakeCollaterals(dpxTokenAddress, 1 ether);

		assertEq(
			mockDpxStakingRewards.balanceOf(address(underTest)),
			0.11 ether
		);
	}

	function test_unstakeCollaterals_asStaker_givenDpxValidAmountAndNotWhitelisted_thenNoRewards()
		public
		prankAs(staker)
	{
		mockDpxStakingRewards.setWhitelistedContracts(
			address(underTest),
			false
		);
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		underTest.unstakeCollaterals(dpxTokenAddress, 1 ether);

		assertEq(mockDpxStakingRewards.balanceOf(address(underTest)), 0 ether);
	}

	function test_unstakeCollaterals_asStaker_givenGmxValidAmount_thenRefundsGmxToStaker()
		public
		prankAs(staker)
	{
		underTest.stakeCollaterals(gmxTokenAddress, 1 ether);
		uint256 staker_gmxBalanceBefore = gmxToken.balanceOf(address(staker));
		underTest.unstakeCollaterals(gmxTokenAddress, 1 ether);
		uint256 staker_gmxBalanceAfter = gmxToken.balanceOf(address(staker));

		assertEq(staker_gmxBalanceAfter - staker_gmxBalanceBefore, 1 ether);
	}

	function test_unstakeCollaterals_asStaker_givenGmxValidAmount_thenReceivesPendingEthRewards()
		public
		prankAs(staker)
	{
		uint256 underTest_ethBalanceBefore = address(underTest).balance;
		underTest.stakeCollaterals(gmxTokenAddress, 1 ether);
		underTest.unstakeCollaterals(gmxTokenAddress, 0.5 ether);
		uint256 underTest_ethBalanceAfter = address(underTest).balance;

		assertEq(
			underTest_ethBalanceAfter - underTest_ethBalanceBefore,
			0.15 ether
		);
	}

	function test_transferGmxAccount_asUser_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(NOT_OWNER);
		underTest.transferGmxAccount(user);
	}

	function test_transferGmxAccount_asOwner_thenTransfersRewardsExceptOriginalStaking()
		public
	{
		vm.prank(staker);
		underTest.stakeCollaterals(gmxTokenAddress, 1 ether);

		vm.startPrank(owner);
		{
			uint256 underTest_ethBalanceBefore = address(underTest).balance;
			uint256 underTest_gmxBalanceBefore = gmxToken.balanceOf(
				address(underTest)
			);
			underTest.transferGmxAccount(user);
			uint256 underTest_ethBalanceAfter = address(underTest).balance;
			uint256 underTest_gmxBalanceAfter = gmxToken.balanceOf(
				address(underTest)
			);

			assertEq(
				underTest_ethBalanceAfter - underTest_ethBalanceBefore,
				0.1 ether
			);
			assertEq(
				underTest_gmxBalanceAfter - underTest_gmxBalanceBefore,
				0 ether
			);
		}
		vm.stopPrank();

		vm.prank(staker);
		underTest.unstakeCollaterals(gmxTokenAddress, 1 ether);
	}

	function test_claimDpxRewards_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(NOT_OWNER);
		underTest.claimDpxRewards(1 ether);
	}

	function test_claimDpxRewards_asOwner_givenTooBigAmount_thenReverts()
		public
		prankAs(owner)
	{
		vm.mockCall(
			address(underTest),
			abi.encodeWithSignature("getClaimableDpxRewards()"),
			abi.encode(1 ether)
		);
		vm.expectRevert(REVERT_INSUFFICIENT_CLAIMABLE_AMOUNT);
		underTest.claimDpxRewards(2 ether);
	}

	function test_claimDpxRewards_asOwner_givenValidAmount_thenClaimsCorrectly()
		public
	{
		vm.startPrank(staker);
		{
			underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
			underTest.unstakeCollaterals(dpxTokenAddress, 1 ether);
		}
		vm.stopPrank();

		vm.startPrank(owner);
		{
			uint256 treasury_dpxBalanceBefore = dpxToken.balanceOf(
				address(treasury)
			);
			underTest.claimDpxRewards(0.11 ether);
			uint256 treasury_dpxBalanceAfter = dpxToken.balanceOf(
				address(treasury)
			);

			assertEq(
				treasury_dpxBalanceAfter - treasury_dpxBalanceBefore,
				0.11 ether
			);

			assertEq(
				mockDpxStakingRewards.balanceOf(address(underTest)),
				0.011 ether
			);
		}
		vm.stopPrank();
	}

	function test_claimETH_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(NOT_OWNER);
		underTest.claimETH(1 ether);
	}

	function test_claimETH_asOwner_givenTooBigAmount_thenReverts()
		public
		prankAs(owner)
	{
		vm.expectRevert(REVERT_INSUFFICIENT_CLAIMABLE_AMOUNT);
		underTest.claimETH(1 ether);
	}

	function test_claimETH_asOwner_givenValidAmount_thenClaimsCorrectly()
		public
	{
		vm.startPrank(staker);
		{
			underTest.stakeCollaterals(gmxTokenAddress, 1 ether);
			underTest.unstakeCollaterals(gmxTokenAddress, 1 ether);
		}
		vm.stopPrank();

		vm.startPrank(owner);
		{
			uint256 treasury_ethBalanceBefore = address(treasury).balance;
			underTest.claimETH(0.1 ether);
			uint256 treasury_ethBalanceAfter = address(treasury).balance;

			assertEq(
				treasury_ethBalanceAfter - treasury_ethBalanceBefore,
				0.1 ether
			);
		}
		vm.stopPrank();
	}

	function test_getAssetDeposited_thenGetCorrectValue()
		public
		prankAs(staker)
	{
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);

		assertEq(underTest.getAssetDeposited(dpxTokenAddress), 2 ether);
	}

	function test_getAssetStaked_thenGetCorrectValue()
		public
		prankAs(staker)
	{
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		mockDpxStakingRewards.setWhitelistedContracts(
			address(underTest),
			false
		);
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);

		assertEq(underTest.getAssetStaked(dpxTokenAddress), 1 ether);
	}

	function test_getAssetBalance_thenGetCorrectValue()
		public
		prankAs(staker)
	{
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);

		assertEq(underTest.getAssetBalance(dpxTokenAddress, staker), 2 ether);
		assertEq(underTest.getAssetBalance(dpxTokenAddress, user), 0 ether);
	}

	function test_getClaimableDpxRewards_thenGetCorrectValue()
		public
		prankAs(staker)
	{
		underTest.stakeCollaterals(dpxTokenAddress, 1 ether);
		vm.mockCall(
			address(mockDpxStakingRewards),
			abi.encodeWithSignature("earned(address)", address(underTest)),
			abi.encode(1 ether, 0)
		);

		assertEq(underTest.getClaimableDpxRewards(), 1.1 ether);
	}

	function test_isSupportedAsset_givenSupportedAsset_thenReturnsTrue()
		public
	{
		assertTrue(underTest.isSupportedAsset(dpxTokenAddress));
		assertTrue(underTest.isSupportedAsset(gmxTokenAddress));
	}

	function test_isSupportedAsset_givenUnsupportedAsset_thenReturnsFalse()
		public
	{
		assertTrue(!underTest.isSupportedAsset(user));
	}

	function test_receive_asUser_sendETH_thenReverts() public prankAs(user) {
		vm.expectRevert(
			abi.encodeWithSignature(REVERT_UNEXPECTED_ETH_RECEIVED, user)
		);
		payable(underTest).transfer(1 ether);
	}
}
