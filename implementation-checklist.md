# Marketplace Manager – Implementation Checklist

## Pre-Development
- [ ] Confirm platform API credentials (eBay sandbox, Mercari, Facebook test app) and redirect URIs.
- [ ] Align data model schema (Products, PlatformListings, Orders, Accounts) and migration plan.
- [ ] Enable CI tasks for linting, unit tests, and Swift format checks.

## Build & Integrations
- [ ] Implement OAuth flows per platform with Keychain storage and refresh tokens.
- [ ] Add API clients with typed endpoints, pagination, retry/backoff, and error mapping.
- [ ] Wire ListingService publish/end flows with optimistic UI and audit logging.
- [ ] Aggregate orders with status updates and duplicate prevention.
- [ ] Compute earnings from orders/fees and expose chart-friendly data.

## Quality & Operations
- [ ] Unit tests for services, API clients, and auth refresh logic.
- [ ] UI tests for publish flow, order detail updates, and error surfaces.
- [ ] Telemetry: structured logs, sync counters, failure reasons; sensitive fields redacted.
- [ ] Offline validation: verify cached data availability and queued sync behavior.

## Pre-Release
- [ ] Sandbox end-to-end test plan executed for each platform.
- [ ] Accessibility and localization scan for primary screens.
- [ ] App Store/TestFlight metadata prepared; feature flags documented.
- [ ] Support playbook drafted for common auth/listing/order issues.
