# EIP-7702 defender checks

**Educational only — do not use against real systems.** Teaching code, not audited.

Companion notes for the video [Binance's $6.3B Hack: 5 Myths Busted + the EIP-7702 Sweeper (Foundry PoC)](https://youtu.be/2bVrMWSz4M0).

This repository is a local Foundry exercise for defenders. It does not connect to a network, it contains no live addresses, and it has no contract that moves funds.

## What defenders need to know

On 29 October 2026, an Ethereum hot wallet was delegated with [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702). A delegated account's code is a 23-byte designator: the prefix `0xef0100` followed by an implementation address. Calls then run that implementation in the wallet's own context, outside the exchange's normal withdrawal pipeline. Pausing withdrawals does not remove the delegation. Until the delegation is cleared, that implementation acts as the wallet.

Two gaps matter for the signing and monitoring stack:

- A monitor that only watches the withdrawal pipeline never sees the delegation. `eth_getCode` on the hot wallet is the signal.
- A signing service that only enforces withdrawal limits will also sign EIP-7702 authorizations, because an authorization is not a withdrawal.

## What this repo checks

Both controls run against local mock accounts only.

1. **Delegation designator check** (`src/DelegationCheck.sol`). Read an account's code and treat a 23-byte value starting with `0xef0100` as a delegation. Empty code, a different prefix, or any other length is not a delegation. Alert when a hot wallet flips to delegated.

2. **Deny-by-default signing policy** (`src/SigningPolicy.sol`). Refuse EIP-7702 authorizations unless the delegate is the zero address (clear an existing delegation) or the organization's pre-approved rescue delegate. Withdrawals above the configured limit are refused as well.

## Run the tests

[Foundry](https://book.getfoundry.sh/) is required.

```bash
git clone --recurse-submodules https://github.com/panditdhamdhere/binance-7702-heist-poc
cd binance-7702-heist-poc
forge test
```

If the clone was not recursive:

```bash
git submodule update --init --recursive
forge test
```

The tests plant designator bytes on local addresses with `vm.etch`. There is no RPC and no fork.
