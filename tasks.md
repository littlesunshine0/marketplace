# Marketplace Manager – Task List

## Active Sprint (Prioritized)
- [ ] Finalize data model schema for Products, PlatformListings, Orders, Accounts, and migrations.
- [ ] Implement OAuth redirect handling per platform and persist tokens in Keychain.
- [ ] Build eBay sandbox listing create/end and order fetch flows with typed responses.
- [ ] Stand up mock adapters for Mercari and Facebook to unblock UI and sync flows.
- [ ] Wire Inventory → Publish flow with optimistic UI state and background sync retries.
- [ ] Add structured logging hooks around API failures, retries, and scheduler runs.
- [ ] Create baseline unit tests for API client serialization and token refresh paths.

## Upcoming (Next Sprint Candidates)
- [ ] Earnings calculations with per-platform breakdowns and chart-friendly aggregates.
- [ ] Duplicate detection and conflict resolution for listing sync jobs.
- [ ] UI tests for publish flow, order updates, and error surfaces.
- [ ] Accessibility and localization audit for primary screens.
- [ ] Telemetry dashboards for sync health (success rates, retry counts, token refreshes).

## Release Gate Checklist (Per Milestone)
- [ ] Sandbox end-to-end test plan executed for eBay, Mercari, and Facebook flows.
- [ ] Error handling verified for rate limits, auth expiry, and platform outages.
- [ ] Support playbook updated with common auth/listing/order issues and recovery steps.
- [ ] App Store/TestFlight metadata prepared; feature flags documented.
