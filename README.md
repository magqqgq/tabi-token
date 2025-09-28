## 1. Overview

- Network: BSC Mainnet (`chainId: 56`, `network: bsc`)
- Proxy Pattern: UUPS (Implementation + ERC1967 Proxy)
- Token: `name: TABI`, `symbol: TABI`, `decimals: 18`
- Generated on: 2025-09-28

---

## 2. Contracts & Addresses

- TABIToken (Implementation)
  - Address: `0x6A381960A1Af80937B0b1EE849cB1aD7c3FD6032`
  - BscScan: https://bscscan.com/address/0x6A381960A1Af80937B0b1EE849cB1aD7c3FD6032

- TABIToken (Proxy, ERC1967Proxy)
  - Address: `0xdF14f38ccdACf43056fDc44BcDf8E2c3ceE88001`
  - BscScan: https://bscscan.com/address/0xdF14f38ccdACf43056fDc44BcDf8E2c3ceE88001

- Initial Admin (at deployment, for AccessControl roles)
  - Address: `0x7F1c622f76Ac6329a8e8371eb955Ca28ED29803a`
  - BscScan: https://bscscan.com/address/0x7F1c622f76Ac6329a8e8371eb955Ca28ED29803a

- Current Admin (DEFAULT_ADMIN_ROLE) — Safe Multisig
  - Address: `0xd8c9237f2b4562384971202A86E608eAdf0ed783`
  - On-chain check (result): `hasRole(DEFAULT_ADMIN_ROLE, Safe) == true`
  - Note: Verified via on-chain call; see Section 5 for the exact command.

---

## 3. Deployment Metadata

- Deployment date: 2025-01-28
- Deployer address: `0x7F1c622f76Ac6329a8e8371eb955Ca28ED29803a`
- Source JSON: `deployments/56/deployment.json`
- File timestamp: `1753426332`
- Gas (from JSON):
  - Gas used: 2,384,141
  - Gas price: 0.1 gwei
  - Estimated cost: 0.0002384141 BNB

---

## 4. Contract Features & Access Model

- Features (Implementation `TABIToken`):
  - ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable
  - AccessControlUpgradeable (roles: `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, `PAUSER_ROLE`)
  - UUPSUpgradeable (upgrades authorized by `_authorizeUpgrade` gated by `DEFAULT_ADMIN_ROLE`)

- Initialization:
  - `initialize(admin)` grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, and `PAUSER_ROLE` to the provided `admin`.
  - For this deployment, the initial admin was `0x7F1c622f76Ac6329a8e8371eb955Ca28ED29803a`.
  - The current admin is a Safe multisig (address to be provided; auditors should verify on-chain).

---

## 5. On-chain Verification Steps

1) ERC1967 Implementation Slot (EIP-1967)

```
cast storage 0xdF14f38ccdACf43056fDc44BcDf8E2c3ceE88001 \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url https://bsc-dataseed.binance.org
```

2) ERC1967 Admin Slot (Note for UUPS / ERC1967Proxy)

```
cast storage 0xdF14f38ccdACf43056fDc44BcDf8E2c3ceE88001 \
  0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 \
  --rpc-url https://bsc-dataseed.binance.org
```

- Explanation: `ERC1967Proxy` used in UUPS pattern does not use the admin slot; this value is typically `0x0`.
  Upgrades are controlled by the implementation logic (UUPS) and gated by `DEFAULT_ADMIN_ROLE` within the token.

3) AccessControl Roles Verification

- Verify current role holders via `hasRole` (on the proxy address).

```
cast call 0xdF14f38ccdACf43056fDc44BcDf8E2c3ceE88001 \
  "hasRole(bytes32,address)(bool)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  0xd8c9237f2b4562384971202A86E608eAdf0ed783 \
  --rpc-url https://bsc-dataseed.binance.org
```

- The zero `bytes32` above corresponds to `DEFAULT_ADMIN_ROLE`. Replace `<ADDRESS_TO_CHECK>` with the Safe multisig and any previous admin to confirm the migration.
  - Example results (as of this document):
    - `hasRole(DEFAULT_ADMIN_ROLE, Safe)` => `true`
    - `hasRole(DEFAULT_ADMIN_ROLE, 0x7F1c622f76Ac6329a8e8371eb955Ca28ED29803a)` => `false`

---

## 6. Risks & Governance Recommendations

- Privilege Separation & Governance
  - Keep `DEFAULT_ADMIN_ROLE` under a Safe multisig.
  - Separate `MINTER_ROLE` and `PAUSER_ROLE` to distinct entities.
  - Consider adding a timelock for upgrades and critical changes.

- Supply Policy
  - No cap is enforced in the current implementation (minting is role-gated).
  - If the business does not require unlimited supply, consider introducing a cap or minting quotas with operational controls.

---

## 7. References

- Source: `src/TABIToken.sol`
- Tests: `test/TABIToken.t.sol` (upgradeability, roles, pause, mint/burn, failure paths)
- Config: `foundry.toml`

---