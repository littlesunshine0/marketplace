# Marketplace Manager – Implementation Plan

## 1. Scope

### In Scope
- Inventory management for uncle’s items.
- Multi-platform listing creation and publishing (eBay, Mercari, Facebook).
- Aggregated orders + earnings dashboards.
- Secure token and credential storage.

### Out of Scope (v1)
- Full-blown shipping label management.
- Advanced repricing rules and automation.
- Team/multi-user access control.

## 2. Deliverables
- SwiftUI iOS/macOS app (universal codebase).
- Service layer for listings, orders, earnings, and auth.
- Configurable sync engine.
- Developer documentation and API notes.

## 3. Workstreams

### A. Architecture & Infrastructure
- Project setup, modules, targets.
- Core Data/SwiftData model definitions.
- Keychain + configuration handling.

### B. Platform APIs
- eBay REST: OAuth2, listing create/end, order fetch.
- Mercari API: listing create/delete, orders.
- Facebook Graph API: Marketplace-compatible flows where allowed.

### C. Application Features
- Inventory CRUD and image handling.
- Multi-platform publish flow (product → platform listings).
- Orders dashboard and status updates.
- Earnings view with time ranges and platform breakdown.

### D. Quality & Operations
- Unit tests for services + API clients.
- UI tests for critical flows.
- Logging, error reporting, and simple analytics.

## 4. Risks & Constraints
- Marketplace API policy changes.
- Rate limits and throttling.
- OAuth UX friction for non-technical users.

## 5. Success Criteria
- Uncle can list an item and publish to ≥2 platforms from one flow.
- Orders and earnings are accurate to within 1% of platforms.
- Sync runs reliably without manual intervention.
