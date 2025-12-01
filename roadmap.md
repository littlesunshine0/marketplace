# Marketplace Manager Roadmap

## Overview
- Goal: Unified app to manage listings, orders, and earnings across marketplaces.
- Timeframe: Q1–Q4 2026.
- Owner: <your-name>

## Phases

### Phase 1 – Foundation (Architecture + Core Models)
- Define Product, PlatformListing, Order, PlatformAccount, Earnings models.
- Set up API client, auth manager, persistence (Core Data/SwiftData, Keychain).
- Create minimal Inventory + Orders views (read-only).

### Phase 2 – Platform Integrations
- Implement eBay REST integration (OAuth2, listings, orders).
- Implement Mercari integration (listings, orders).
- Implement Facebook Marketplace integration (Graph API where allowed).
- Centralized error + rate-limit handling.

### Phase 3 – Multi-Platform Workflows
- In-app listing creation → publish to multiple platforms.
- Order aggregation dashboard with filters.
- Earnings calculations and per-platform breakdown.

### Phase 4 – UX, Performance, Reliability
- Offline-first sync strategy and conflict resolution.
- Performance tuning (batching, caching, pagination).
- Telemetry/logging hooks and diagnostics.

### Phase 5 – Release & Expansion
- Beta with real seller accounts.
- Documentation, onboarding flows, and help content.
- Evaluate additional platforms (Poshmark, Vinted, etc.).
