// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DelegationCheck} from "../src/DelegationCheck.sol";
import {SigningPolicy} from "../src/SigningPolicy.sol";

/// @notice Local checks only. Designator bytes are etched onto mock accounts.
///         No fork, no live addresses, no fund movement.
contract DefenderControlsTest is Test {
    address internal rescue = makeAddr("rescue delegate");
    address internal hot = makeAddr("hot wallet");

    uint256 internal constant MAX_WITHDRAWAL = 1_000 ether;

    SigningPolicy internal policy;

    function setUp() public {
        policy = new SigningPolicy(rescue, MAX_WITHDRAWAL);
    }

    function _designator(address implementation) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"ef0100", implementation);
    }

    function test_plainAccountIsNotDelegated() public view {
        (bool delegated, address target) = DelegationCheck.delegateOf(hot);
        assertFalse(delegated);
        assertEq(target, address(0));
        assertEq(hot.code.length, 0);
    }

    function test_designatorIsDetected() public {
        address implementation = makeAddr("implementation");
        vm.etch(hot, _designator(implementation));

        (bool delegated, address target) = DelegationCheck.delegateOf(hot);
        assertTrue(delegated);
        assertEq(target, implementation);
        assertEq(hot.code.length, 23);
    }

    function test_wrongPrefixIsNotDelegated() public {
        vm.etch(hot, abi.encodePacked(hex"ef0001", makeAddr("implementation")));

        (bool delegated, address target) = DelegationCheck.delegateOf(hot);
        assertFalse(delegated);
        assertEq(target, address(0));
    }

    function test_wrongLengthIsNotDelegated() public {
        vm.etch(hot, hex"deadbeef");
        (bool shortDelegated, address shortTarget) = DelegationCheck.delegateOf(hot);
        assertFalse(shortDelegated);
        assertEq(shortTarget, address(0));
        assertEq(hot.code.length, 4);

        // Longer runtime code is not a 23-byte designator.
        bytes memory runtime = abi.encodePacked(hex"60806040", bytes32("not a designator"));
        vm.etch(hot, runtime);
        (bool longDelegated, address longTarget) = DelegationCheck.delegateOf(hot);
        assertFalse(longDelegated);
        assertEq(longTarget, address(0));
        assertEq(hot.code.length, runtime.length);
        assertTrue(runtime.length != 23);
    }

    function test_withdrawalAtLimitIsAllowed() public {
        assertTrue(
            policy.check(SigningPolicy.Kind.Withdrawal, makeAddr("destination"), MAX_WITHDRAWAL)
        );
    }

    function test_withdrawalOverLimitIsDenied() public {
        vm.expectRevert(
            abi.encodeWithSelector(SigningPolicy.PolicyDenied.selector, "withdrawal over limit")
        );
        policy.check(SigningPolicy.Kind.Withdrawal, makeAddr("destination"), MAX_WITHDRAWAL + 1);
    }

    function test_unexpectedDelegationIsDenied() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                SigningPolicy.PolicyDenied.selector, "7702 delegation not allowed"
            )
        );
        policy.check(SigningPolicy.Kind.Authorization7702, makeAddr("unexpected delegate"), 0);
    }

    function test_revokeToZeroIsAllowed() public view {
        assertTrue(policy.check(SigningPolicy.Kind.Authorization7702, address(0), 0));
    }

    function test_preapprovedRescueDelegateIsAllowed() public view {
        assertTrue(policy.check(SigningPolicy.Kind.Authorization7702, rescue, 0));
    }
}
