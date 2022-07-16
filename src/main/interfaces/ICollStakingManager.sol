// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface ICollStakingManager {
	// --- Custom Errors ---
	error CallerIsNotWhitelisted(address _caller);

	error ZeroAmountPassed();

	error ZeroAddressPassed();

	error InsufficientBalance();

	error InsufficientClaimableAmount();

	error NotSupportedAsset(address _asset);

	error EthTransferFailed();

	error UnexpectedEthReceived(address _sender);

	// --- Events ---
	event TreasuryAddressChanged(address indexed _newTreasuryAddress);

	event AddressWhitelisted(address indexed _addr, bool whitelisted);

	event AssetStaked(
		address indexed _staker,
		uint256 _depositedAmount,
		uint256 _stakedAmount
	);

	event AssetUnstaked(address indexed _staker, uint256 _unstakedAmount);

	// --- External Functions ---
	function getAssetDeposited(address _asset)
		external
		view
		returns (uint256);

	function getAssetStaked(address _asset) external view returns (uint256);

	function getAssetBalance(address _asset, address _staker)
		external
		view
		returns (uint256);

	function getClaimableDpxRewards() external view returns (uint256);

	function isSupportedAsset(address _asset) external view returns (bool);

	function stakeCollaterals(address _asset, uint256 _amount) external;

	function unstakeCollaterals(address _asset, uint256 _amount) external;
}
