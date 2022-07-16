// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import { DSTest } from "ds-test/test.sol";

import { VM } from "../utils/VM.sol";
import { console } from "../utils/console.sol";
import "../utils/Accounts.sol";

contract BaseTest is DSTest {
	VM internal constant vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
	Accounts internal accountsDb = new Accounts(vm);

	bytes internal constant NOT_OWNER = "Ownable: caller is not the owner";
	bytes internal constant ERC20_INVALID_BALANCE =
		"ERC20: transfer amount exceeds balance";

	modifier prankAs(address caller) {
		vm.startPrank(caller);
		_;
		vm.stopPrank();
	}
}
