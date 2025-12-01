# Marketplace Manager – Implementation Plan

## 1. Scope

### In Scope
- Inventory management for uncle’s items.
- Multi-platform listing creation and publishing (eBay, Mercari, Facebook).
- Aggregated orders + earnings dashboards.
- Secure token and credential storage.
- Offline-friendly sync with retries and conflict handling for listings and orders.

### Out of Scope (v1)
- Full-blown shipping label management.
- Advanced repricing rules and automation.
- Team/multi-user access control.
- Cross-border tax automation.

## 2. Deliverables
- SwiftUI iOS/macOS app (universal codebase).
- Service layer for listings, orders, earnings, and auth.
- Configurable sync engine.
- Developer documentation and API notes.
- Testable mock API harness for eBay/Mercari/Facebook sandbox flows.

## 3. Workstreams

### A. Architecture & Infrastructure
- Project setup, modules, targets.
- Core Data/SwiftData model definitions.
- Keychain + configuration handling.
- Sync scheduler (foreground + background refresh) with exponential backoff.

### B. Platform APIs
- eBay REST: OAuth2, listing create/end, order fetch.
- Mercari API: listing create/delete, orders.
- Facebook Graph API: Marketplace-compatible flows where allowed.
- Shared API client behaviors: pagination, throttling, structured errors.

### C. Application Features
- Inventory CRUD and image handling.
- Multi-platform publish flow (product → platform listings).
- Orders dashboard and status updates.
- Earnings view with time ranges and platform breakdown.
- Notification hooks for listing success/failure and new orders.

### D. Quality & Operations
- Unit tests for services + API clients.
- UI tests for critical flows.
- Logging, error reporting, and simple analytics.
- Release checklist (TestFlight/beta readiness, smoke tests, migration checks).

## 4. Risks & Constraints
- Marketplace API policy changes.
- Rate limits and throttling.
- OAuth UX friction for non-technical users.
- App Store review constraints for Marketplace permissions.

## 5. Success Criteria
- Uncle can list an item and publish to ≥2 platforms from one flow.
- Orders and earnings are accurate to within 1% of platforms.
- Sync runs reliably without manual intervention.
- Major API operations retried automatically with backoff and surfaced errors.

## 6. Near-Term Tasks (Next 2 Sprints)
- Finalize data model schema and migration strategy for Products/Orders/Listings.
- Wire OAuth redirect handling per platform and store tokens in Keychain.
- Implement eBay listing create/end + order fetch via sandbox.
- Stand up mock adapters for Mercari/Facebook to unblock UI work.
- Build Inventory → Publish flow with optimistic UI and background sync retries.
- Add logging hooks around API failures and sync scheduler executions.
- Create baseline unit tests for API client serialization and auth refresh.
