// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

interface IDPXStakingRewards {
  // Views
  function lastTimeRewardApplicable() external view returns (uint256);

  function rewardPerToken() external view returns (uint256, uint256);

  function earned(address account) external view returns (uint256, uint256);

  function getRewardForDuration() external view returns (uint256, uint256);

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function whitelistedContracts(address addr) external view returns (bool);

  // Mutative

  function stake(uint256 amount) external payable;

  function withdraw(uint256 amount) external;

  function getReward(uint256 rewardsTokenID) external;

  function compound() external;

  function exit() external;
}