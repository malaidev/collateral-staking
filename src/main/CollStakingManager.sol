// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/TransferHelper.sol";
import "./interfaces/ICollStakingManager.sol";

import "./interfaces/dpx/IDPXStakingRewards.sol";
import "./interfaces/gmx/IGMXRewardRouterV2.sol";

/*
 * The Collateral Staking stakes the collaterals saved on Active Pool to get passive income
 *
 * When the active pool is required to send the asset back to the trove owner or stability pool,
 * it immediately withdraws the principal amount of staking and compounds the rewards for continuous earnings
 *
 */
contract CollStakingManager is OwnableUpgradeable, ICollStakingManager {
	address public treasuryAddress;
	address public dpxToken;
	address public gmxToken;

	IDPXStakingRewards public dpxStakingRewards;
	IGMXRewardRouterV2 public gmxRewardRouterV2;

	mapping(address => bool) public whitelisted;

	mapping(address => uint256) internal assetsDeposited;
	mapping(address => uint256) internal assetsStaked;

	mapping(address => mapping(address => uint256)) internal balances;

	modifier callerIsWhitelisted() {
		if (!whitelisted[msg.sender]) {
			revert CallerIsNotWhitelisted(msg.sender);
		}
		_;
	}

	modifier checkNonZero(uint256 _amount) {
		if (_amount == 0) revert ZeroAmountPassed();
		_;
	}

	modifier checkNonZeroAddress(address _addr) {
		if (_addr == address(0)) revert ZeroAddressPassed();
		_;
	}

	modifier supportedAsset(address _asset) {
		if (!isSupportedAsset(_asset)) {
			revert NotSupportedAsset(_asset);
		}
		_;
	}

	function setUp(
		address _treasuryAddress,
		address _dpxToken,
		address _gmxToken,
		address _dpxStakingRewards,
		address _gmxRewardRouterV2
	) external initializer {
		if (
			_treasuryAddress == address(0) ||
			_dpxToken == address(0) ||
			_gmxToken == address(0) ||
			_dpxStakingRewards == address(0) ||
			_gmxRewardRouterV2 == address(0)
		) revert ZeroAddressPassed();

		__Ownable_init();

		treasuryAddress = _treasuryAddress;
		dpxToken = _dpxToken;
		gmxToken = _gmxToken;
		dpxStakingRewards = IDPXStakingRewards(_dpxStakingRewards);
		gmxRewardRouterV2 = IGMXRewardRouterV2(_gmxRewardRouterV2);
	}

	function stakeCollaterals(address _asset, uint256 _amount)
		external
		override
		callerIsWhitelisted
		supportedAsset(_asset)
		checkNonZero(_amount)
	{
		assetsDeposited[_asset] += _amount;
		balances[_asset][msg.sender] += _amount;

		TransferHelper.safeTransferFrom(
			_asset,
			msg.sender,
			address(this),
			_amount
		);

		_stakeCollaterals(_asset);
	}

	function unstakeCollaterals(address _asset, uint256 _amount)
		external
		override
		supportedAsset(_asset)
		checkNonZero(_amount)
	{
		if (balances[_asset][msg.sender] < _amount) {
			revert InsufficientBalance();
		}

		_unstakeCollaterals(_asset, _amount);

		assetsDeposited[_asset] -= _amount;
		balances[_asset][msg.sender] -= _amount;

		TransferHelper.safeTransfer(_asset, msg.sender, _amount);
	}

	function _stakeCollaterals(address _asset) internal {
		uint256 stakingAmount = IERC20(_asset).balanceOf(address(this));

		if (_asset == dpxToken) {
			if (dpxStakingRewards.whitelistedContracts(address(this))) {
				TransferHelper.safeApprove(
					_asset,
					address(dpxStakingRewards),
					stakingAmount
				);
				dpxStakingRewards.stake(stakingAmount);
			} else {
				stakingAmount = 0;
			}
		} else if (_asset == gmxToken) {
			TransferHelper.safeApprove(
				_asset,
				address(gmxRewardRouterV2),
				stakingAmount
			);
			gmxRewardRouterV2.stakeGmx(stakingAmount);
		}

		assetsStaked[_asset] += stakingAmount;

		_compoundStaking(_asset);
	}

	function _unstakeCollaterals(address _asset, uint256 _amount) internal {
		uint256 withdrawalAmount = assetsStaked[_asset] < _amount
			? assetsStaked[_asset]
			: _amount;

		if (_asset == dpxToken) {
			dpxStakingRewards.withdraw(withdrawalAmount);
		} else if (_asset == gmxToken) {
			gmxRewardRouterV2.unstakeGmx(withdrawalAmount);
		}

		assetsStaked[_asset] -= withdrawalAmount;

		_compoundStaking(_asset);
	}

	function _compoundStaking(address _asset) internal {
		if (_asset == dpxToken) {
			(uint256 dpxEarned, ) = dpxStakingRewards.earned(address(this));
			if (dpxEarned > 0) {
				dpxStakingRewards.compound();
			}
		} else if (_asset == gmxToken) {
			gmxRewardRouterV2.handleRewards(
				true,
				true,
				true,
				true,
				true,
				true,
				true
			);
		}
	}

	function claimETH(uint256 _amount)
		external
		checkNonZero(_amount)
		onlyOwner
	{
		uint256 claimableAmount = address(this).balance;
		if (_amount > claimableAmount) revert InsufficientClaimableAmount();

		(bool success, ) = treasuryAddress.call{ value: _amount }("");
		if (!success) revert EthTransferFailed();
	}

	function claimDpxRewards(uint256 _amount)
		external
		checkNonZero(_amount)
		onlyOwner
	{
		uint256 claimableAmount = getClaimableDpxRewards();
		if (_amount > claimableAmount) revert InsufficientClaimableAmount();

		dpxStakingRewards.compound();
		dpxStakingRewards.withdraw(_amount);

		TransferHelper.safeTransfer(dpxToken, treasuryAddress, _amount);
	}

	function transferGmxAccount(address _receiver) external onlyOwner {
		_unstakeCollaterals(gmxToken, assetsStaked[gmxToken]);
		gmxRewardRouterV2.signalTransfer(_receiver);
		_stakeCollaterals(gmxToken);
	}

	function setTreasuryAddress(address _treasuryAddress)
		external
		checkNonZeroAddress(_treasuryAddress)
		onlyOwner
	{
		treasuryAddress = _treasuryAddress;

		emit TreasuryAddressChanged(treasuryAddress);
	}

	function setWhitelistAddress(address _addr, bool _enabled)
		external
		checkNonZeroAddress(_addr)
		onlyOwner
	{
		whitelisted[_addr] = _enabled;
	}

	function getAssetDeposited(address _asset)
		external
		view
		override
		returns (uint256)
	{
		return assetsDeposited[_asset];
	}

	function getAssetStaked(address _asset)
		external
		view
		override
		returns (uint256)
	{
		return assetsStaked[_asset];
	}

	function getAssetBalance(address _asset, address _staker)
		external
		view
		override
		returns (uint256)
	{
		return balances[_asset][_staker];
	}

	function getClaimableDpxRewards()
		public
		view
		override
		returns (uint256)
	{
		(uint256 dpxEarned, ) = dpxStakingRewards.earned(address(this));
		uint256 totalBalance = dpxStakingRewards.balanceOf(address(this)) +
			dpxEarned;
		return totalBalance - assetsStaked[dpxToken];
	}

	function isSupportedAsset(address _asset)
		public
		view
		override
		returns (bool)
	{
		return _asset == dpxToken || _asset == gmxToken;
	}

	receive() external payable {
		if (msg.sender != address(gmxRewardRouterV2)) {
			revert UnexpectedEthReceived(msg.sender);
		}
	}
}
