# Gather Backend — Ruby on Rails API

This is a Rails API backend for Gather's secure document collection workflow. It includes multi-tenant companies, admin users, contacts, invites, request items, client magic-link sessions, presigned S3/MinIO upload URLs, approval/rejection workflows, audit events, email jobs, and Sidekiq background processing.

## Stack

- Ruby on Rails 7 API mode
- PostgreSQL
- Redis + Sidekiq
- S3-compatible object storage; Docker uses MinIO
- JWT auth for admins and clients
- bcrypt password hashing
- AWS SDK presigned upload/download URLs

## Run locally with Docker

```bash
docker compose up --build
```

The API will run at:

```text
http://localhost:3000
```

MinIO console:

```text
http://localhost:9001
username: minioadmin
password: minioadmin
```

Seed data is created by running:

```bash
docker compose exec api bundle exec rails db:seed
```

Demo login after seeding:

```text
admin@example.com / password123
```

## Main endpoints

### Admin

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/me`
- `GET /api/v1/contacts`
- `POST /api/v1/contacts`
- `GET /api/v1/invites`
- `POST /api/v1/invites`
- `POST /api/v1/invites/bulk_create`
- `POST /api/v1/invites/:id/send_invite`
- `POST /api/v1/uploaded_files/:id/approve`
- `POST /api/v1/uploaded_files/:id/reject`
- `GET /api/v1/uploaded_files/:id/download_url`

### Client portal

- `POST /api/v1/client/magic-link`
- `POST /api/v1/client/sessions`
- `GET /api/v1/client/invites/:public_token`
- `POST /api/v1/client/request-items/:id/upload-url`
- `POST /api/v1/client/request-items/:id/complete-upload`

## Production hardening checklist

Before production use, add:

- Admin MFA
- Email-based magic link delivery instead of returning the token
- S3 bucket policy with encryption and object ownership controls
- Virus scanning pipeline for uploaded files
- File type validation and size limits
- Rate limits for auth/magic-link endpoints
- SAML/OIDC SSO for enterprise customers
- Tenant-aware authorization tests
- Webhooks and integration event replay
- Data retention/deletion policies
- SOC 2 controls for access review, audit logs, backups, vulnerability management, and change management

## Notes

This is a backend starter application. It intentionally keeps the client magic-link endpoint developer-friendly by returning the token directly. In production, the token should only be sent by email/SMS.

## Daily uncollected documents summary

Run the daily summary job manually:

```bash
bundle exec rake gather:send_daily_uncollected_documents_summary
```

Schedule this task to run once per day (for example with cron or your Sidekiq scheduler) to email contacts with outstanding request items.

### Configuration

Control the daily schedule with the `DAILY_SUMMARY_CRON` environment variable (cron expression format):

```bash
# Run at 13:00 UTC daily (default)
DAILY_SUMMARY_CRON="0 13 * * *" 

# Run at 08:00 UTC daily
DAILY_SUMMARY_CRON="0 8 * * *"

# Run every 6 hours
DAILY_SUMMARY_CRON="0 */6 * * *"
```
