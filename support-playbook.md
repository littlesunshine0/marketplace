# Support Playbook – Auth/Listing/Order Recovery

- **Auth failures (401/invalid token)**: trigger `AuthenticationManager.refreshToken` and prompt user to reconnect via OAuth redirect handler. Persist refreshed token in `KeychainManager`; log with category `auth`.
- **Rate limits**: surface `APIError.rateLimited`, backoff scheduler, and requeue publish jobs in `ListingService.retryFailedPublishes`.
- **Listing publish errors**: mark `PublishJob` as failed, show last error, and allow retries from background scheduler.
- **Order sync conflicts**: `OrderAggregatorService.resolveDuplicates` keeps newest by `updatedAt` and logs a warning for investigation.
- **Telemetry**: monitor `TelemetryService.metrics` for retry spikes and token refresh counts; escalate when retryCount increases over baseline.
