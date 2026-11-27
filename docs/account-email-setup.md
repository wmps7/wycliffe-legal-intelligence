# Account email configuration

The live site uses Supabase Auth and a private research-notes table. Email verification remains enabled. The administrator notification queue is private, and the worker is designed to send approved registration data only after confirmation and acknowledgement of the registration notice. Do not activate the worker until delivery credentials are securely configured.

1. Obtain an authenticated sender domain and verify it in Resend. Set Supabase Auth custom SMTP in the dashboard, following https://supabase.com/docs/guides/auth/auth-smtp.
2. Deploy the registration-notifications function with JWT gateway verification enabled or the documented service-to-service configuration, and keep its independent worker token check.
3. Set RESEND_API_KEY, WLI_NOTIFICATION_FROM, WLI_NOTIFICATION_TO and a strong WLI_WORKER_TOKEN as server-side secrets. Never include them in GitHub or browser JavaScript.
4. Store the scheduler authentication in Supabase Vault and configure an authenticated scheduled POST call. See https://supabase.com/docs/guides/functions/schedule-functions.
5. Test with an authorised test account before opening public registration. Confirm delivery and that the queue marks the registration delivered once. The worker retries failed deliveries up to five times, with a 15-minute lease. Provider idempotency is time limited, so investigate uncertain deliveries before retrying old notifications.

Google sign-in requires a Google Cloud OAuth client configured for the Supabase callback and production website, Google account two-step verification, and any required consent or verification. Do not expose the OAuth client secret.

Current live account management is available inside the private Supabase Authentication dashboard. No email delivery or OAuth is claimed operational until configured and tested.
