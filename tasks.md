# Marketplace Manager – Task List

## Active Sprint (Prioritized)
- [x] Finalize data model schema for Products, PlatformListings, Orders, Accounts, and migrations.
- [x] Implement OAuth redirect handling per platform and persist tokens in Keychain.
- [x] Build eBay sandbox listing create/end and order fetch flows with typed responses.
- [x] Stand up mock adapters for Mercari and Facebook to unblock UI and sync flows.
- [x] Wire Inventory → Publish flow with optimistic UI state and background sync retries.
- [x] Add structured logging hooks around API failures, retries, and scheduler runs.
- [x] Create baseline unit tests for API client serialization and token refresh paths.

## Upcoming (Next Sprint Candidates)
- [x] Earnings calculations with per-platform breakdowns and chart-friendly aggregates.
- [x] Duplicate detection and conflict resolution for listing sync jobs.
- [x] UI tests for publish flow, order updates, and error surfaces.
- [x] Accessibility and localization audit for primary screens.
- [x] Telemetry dashboards for sync health (success rates, retry counts, token refreshes).

## Release Gate Checklist (Per Milestone)
- [x] Sandbox end-to-end test plan executed for eBay, Mercari, and Facebook flows.
- [x] Error handling verified for rate limits, auth expiry, and platform outages.
- [x] Support playbook updated with common auth/listing/order issues and recovery steps.
- [x] App Store/TestFlight metadata prepared; feature flags documented.
