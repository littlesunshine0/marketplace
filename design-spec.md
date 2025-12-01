# Marketplace Manager – Design Specification

## Architecture Decisions
- **Presentation:** SwiftUI with Observable view models per feature (Inventory, Orders, Earnings, Settings).
- **Services:** ListingService, OrderAggregatorService, EarningsService, AuthManager; each service owns platform-agnostic logic.
- **API Clients:** One client per platform implementing a shared APIEndpoint protocol; base APIClient handles retries, auth injection, and decoding.
- **Persistence:** Core Data/SwiftData for products/orders/listings; Keychain for tokens; UserDefaults for lightweight settings.
- **Sync:** Foreground timer + background tasks trigger platform fetch/publish jobs; retries use exponential backoff with jitter.

## Data Flows
1. **Inventory → Publish**: Product drafted locally → user selects target platforms → ListingService orchestrates platform client calls → results persisted with audit trail.
2. **Orders Aggregation**: OrderAggregatorService queries each platform client → normalizes responses to Order models → caches locally → view models emit updates.
3. **Auth Lifecycle**: AuthManager initiates OAuth → stores tokens in Keychain → injects access tokens into APIClient → refreshes before expiry; errors bubble to SettingsView for remediation.
4. **Earnings**: EarningsService reads Orders + fees → computes per-platform/timeframe totals → exposes to EarningsView with chart-friendly series.

## Error Handling Strategy
- Use typed errors for network, auth, validation, and platform rate limits.
- Circuit breaker for repeated platform failures to avoid hammering APIs; surface status in Settings.
- Redact sensitive payloads in logs; include correlation IDs for server traces when available.

## UX & Accessibility Notes
- Optimistic updates for listing actions with rollback if platform rejects request.
- Clear status badges for listings (Draft, Published, Syncing, Error) and orders (New, Shipped, Completed).
- Support Dynamic Type and VoiceOver labels across major views.
- Provide manual sync controls and surfaced timestamps for last successful sync per platform.

## Testing Strategy
- Unit tests for services and API clients using mock adapters.
- Integration smoke tests per platform using sandbox endpoints.
- UI tests for publish flow, order detail updates, and auth re-login.
- Migration tests for Core Data/SwiftData schema changes.
