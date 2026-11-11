// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Monitor helper for EIP-7702. A delegated account's code is exactly
///         23 bytes: the prefix 0xef0100 followed by the implementation address.
///         Any other code length or prefix is not a delegation designator.
library DelegationCheck {
    function delegateOf(address account)
        internal
        view
        returns (bool delegated, address implementation)
    {
        bytes memory code = account.code;
        if (code.length != 23) return (false, address(0));
        if (code[0] != 0xef || code[1] != 0x01 || code[2] != 0x00) {
            return (false, address(0));
        }

        bytes20 raw;
        for (uint256 i; i < 20; ++i) {
            raw |= bytes20(code[3 + i]) >> (i * 8);
        }
        return (true, address(raw));
    }
}
