// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Deny-by-default gate for an internal signing service.
///         Withdrawals are allowed only up to a configured limit.
///         EIP-7702 authorizations are refused unless the delegate is the zero
///         address (clear an existing delegation) or the organization's
///         pre-approved rescue delegate.
contract SigningPolicy {
    enum Kind {
        Withdrawal,
        Authorization7702
    }

    address public immutable rescueDelegate;
    uint256 public immutable maxWithdrawal;

    error PolicyDenied(string why);

    constructor(address rescueDelegate_, uint256 maxWithdrawal_) {
        rescueDelegate = rescueDelegate_;
        maxWithdrawal = maxWithdrawal_;
    }

    /// @return true when the service would produce a signature for this request.
    function check(Kind kind, address target, uint256 amount) external view returns (bool) {
        if (kind == Kind.Withdrawal) {
            if (amount > maxWithdrawal) revert PolicyDenied("withdrawal over limit");
            return true;
        }
        if (target == address(0) || target == rescueDelegate) return true;
        revert PolicyDenied("7702 delegation not allowed");
    }
}
