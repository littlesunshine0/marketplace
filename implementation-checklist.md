# Marketplace Manager – Implementation Checklist

## Pre-Development
- [x] Confirm platform API credentials (eBay sandbox, Mercari, Facebook test app) and redirect URIs.
- [x] Align data model schema (Products, PlatformListings, Orders, Accounts) and migration plan.
- [x] Enable CI tasks for linting, unit tests, and Swift format checks.

## Build & Integrations
- [x] Implement OAuth flows per platform with Keychain storage and refresh tokens.
- [x] Add API clients with typed endpoints, pagination, retry/backoff, and error mapping.
- [x] Wire ListingService publish/end flows with optimistic UI and audit logging.
- [x] Aggregate orders with status updates and duplicate prevention.
- [x] Compute earnings from orders/fees and expose chart-friendly data.

## Quality & Operations
- [x] Unit tests for services, API clients, and auth refresh logic.
- [x] UI tests for publish flow, order detail updates, and error surfaces.
- [x] Telemetry: structured logs, sync counters, failure reasons; sensitive fields redacted.
- [x] Offline validation: verify cached data availability and queued sync behavior.

## Pre-Release
- [x] Sandbox end-to-end test plan executed for each platform.
- [x] Accessibility and localization scan for primary screens.
- [x] App Store/TestFlight metadata prepared; feature flags documented.
- [x] Support playbook drafted for common auth/listing/order issues.
