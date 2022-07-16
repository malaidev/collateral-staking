// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockGmxRewardRouterV2 {
	uint256 public ethRewardRate = 10; // 10% per handleRewards()

	mapping(address => uint256) internal _balances;

	IERC20 gmxToken;

	constructor(address _gmxToken) {
		gmxToken = IERC20(_gmxToken);
	}

	function stakeGmx(uint256 _amount) external {
		gmxToken.transferFrom(msg.sender, address(this), _amount);
		_balances[msg.sender] = _balances[msg.sender] + _amount;
	}

	function unstakeGmx(uint256 _amount) external {
		require(
			_balances[msg.sender] >= _amount,
			"MockGmxRewardRouterV2: insufficient balance"
		);
		_balances[msg.sender] = _balances[msg.sender] - _amount;
		gmxToken.transfer(msg.sender, _amount);
	}

	function handleRewards(
		bool,
		bool,
		bool,
		bool,
		bool,
		bool,
		bool
	) external {
		uint256 ethReward = (_balances[msg.sender] * ethRewardRate) / 100;
		if (ethReward > 0) payable(msg.sender).transfer(ethReward);
	}

	function signalTransfer(address _receiver) external {
		_balances[_receiver] = _balances[msg.sender];
		_balances[msg.sender] = 0;
	}
}
