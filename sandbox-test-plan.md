# Sandbox End-to-End Test Plan

1. **OAuth Redirect & Token Capture**
   - Trigger OAuth for eBay, Mercari, Facebook sandbox apps.
   - Confirm `OAuthRedirectHandler.handleRedirect` stores tokens in Keychain and persists `PlatformAccount` per platform.
2. **Listing Lifecycle**
   - Create product, publish to all platforms via `ListingService.publishToAllPlatforms`.
   - Verify platform listing IDs recorded and `publishJobs` move to `succeeded`.
   - End/delete listings and ensure local records removed.
3. **Order Sync**
   - Use mock orders from adapters, run `Scheduler.runSyncCycle`, and confirm orders persisted without duplicates.
4. **Telemetry & Logging**
   - Inspect log output categories (`network`, `listing.publish`, `scheduler`, `auth`) for success/failure traces.
   - Ensure `TelemetryService.metrics` increments for sync success and retries.
