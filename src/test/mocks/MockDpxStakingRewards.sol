// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockDpxStakingRewards {
	uint256 public rewardRate = 10; // 10% per compound()

	mapping(address => bool) internal _whitelistedContracts;
	mapping(address => uint256) internal _balances;

	IERC20 dpxToken;

	constructor(address _dpxToken) {
		dpxToken = IERC20(_dpxToken);
	}

	function balanceOf(address account) external view returns (uint256) {
		return _balances[account];
	}

	function whitelistedContracts(address addr)
		external
		view
		returns (bool)
	{
		return _whitelistedContracts[addr];
	}

	function earned(address account) public view returns (uint256, uint256) {
		uint256 _earnedDpx = (_balances[account] * rewardRate) / 100;

		return (_earnedDpx, 0);
	}

	function setWhitelistedContracts(address addr, bool enabled) external {
		_whitelistedContracts[addr] = enabled;
	}

	function stake(uint256 amount) external payable {
		require(
			_whitelistedContracts[msg.sender],
			"MockDpxStakingRewards: caller contract not whitelisted"
		);
		dpxToken.transferFrom(msg.sender, address(this), amount);
		_balances[msg.sender] = _balances[msg.sender] + amount;
	}

	function withdraw(uint256 amount) external {
		require(
			_balances[msg.sender] >= amount,
			"MockDpxStakingRewards: insufficient balance"
		);
		_balances[msg.sender] = _balances[msg.sender] - amount;
		dpxToken.transfer(msg.sender, amount);
	}

	function compound() external {
		(uint256 _earnedDpx, ) = earned(msg.sender);
		_balances[msg.sender] = _balances[msg.sender] + _earnedDpx;
	}
}
