---
bump: minor
---

Sync the generated client and types with the Turnkey API.

- Add swaps: `createSwapQuote` (sends `ACTIVITY_TYPE_CREATE_SWAP_QUOTE_V3`, with optional `feeSponsorship` and `fixedRate`), `executeSwap` (`ACTIVITY_TYPE_EXECUTE_SWAP_V3`), `getSwapStatus`, `upsertSwapConfig`, and `claimSwapFees`.
- Add swap fee sponsorship and fixed-rate controls: `upsertSwapFeeSponsorshipLimitConfig`, `upsertSwapFixedRateLimitConfig`, and `getSwapSponsorshipUsage`.
- Add the other API methods released since the last sync, including Earn, fiat on-ramp quotes and sessions, external signer tasks, and TVC operators and quorum keys.
- `ethSendTransaction` and `solSendTransaction` keep sending their V1 activities with the same request bodies. The API's default moved to V2, and the code generator now builds pinned activities' bodies from the pinned intent.
- Matches API changes already live: `FiatOnRampBlockchainNetwork.bitcoin` is removed, and `nonce` is required on OAuth2 authenticate.
- Add the Spark mainnet and regtest address formats to the default payload encodings.
