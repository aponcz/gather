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

## Stage deployment

The `Deploy backend to stage` GitHub Actions workflow runs on pushes to `master`
that change `backend/**` or the workflow itself, and can also be run manually.
It builds `backend/Dockerfile`, pushes a uniquely tagged image to
`195698602349.dkr.ecr.us-east-1.amazonaws.com/stage/gather-backend`, and deploys
the image by digest to the existing service in
`arn:aws:ecs:us-east-1:195698602349:cluster/stage-ecs-cluster`.

Configure these GitHub **stage environment variables** before running it:

| Variable | Value |
| --- | --- |
| `BACKEND_ECS_SERVICE` | Optional override; defaults to `stage-gather-web` |
| `BACKEND_ECS_CONTAINER` | Required: backend container name in that service's task definition |

The ECR repository, ECS service, and initial task definition must already exist.
The service must use the ECS rolling deployment controller. The workflow reads
the service's current task definition, preserves its configuration, detects its
CPU architecture, and replaces the selected container's image. Other containers
and separate worker services are not updated. Deployments run serially and wait
for ECS service stability.

AWS authentication uses GitHub OIDC with
`arn:aws:iam::195698602349:role/gather-stage-github-oidc-role`; no long-lived AWS
keys are needed. Its trust policy must allow this repository's `stage`
environment (`repo:OWNER/REPOSITORY:environment:stage`, audience
`sts.amazonaws.com`). The role needs:

- `ecr:GetAuthorizationToken` on `*`.
- `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`,
  `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, and `ecr:PutImage` on
  `arn:aws:ecr:us-east-1:195698602349:repository/stage/gather-backend`.
- `ecs:DescribeServices` and `ecs:UpdateService` for the backend service.
- `ecs:DescribeTaskDefinition` and `ecs:RegisterTaskDefinition` on `*`.
- `iam:PassRole` for the task and execution roles referenced by the task definition.

Keep runtime configuration and secrets in the ECS task definition and its secret
references, including `RAILS_ENV=production`, database/Redis connections, and Rails
secrets. The Dockerfile runs `rails db:prepare` before starting Puma, so the task
needs database connectivity and migration permissions. Use migrations compatible
with the previous version while ECS performs a rolling update.

The workflow follows the AWS
[ECS deployment action](https://github.com/aws-actions/amazon-ecs-deploy-task-definition)
and [ECR login action](https://github.com/aws-actions/amazon-ecr-login) guidance.

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

## Custom domain support

Companies can use their own custom domains instead of subdomains to access the application. This is useful for white-labeling and branded experiences.

### Configuration

When a company registers or updates their profile, they can set a `custom_domain` field (e.g., `documents.mycompany.com`). The application will automatically route requests to the correct company based on:

1. Custom domain (if set and matches the request hostname)
2. Subdomain (if custom domain is not set)

Example registration with custom domain:

```bash
POST /api/v1/auth/register
{
  "company_name": "Acme Corp",
  "name": "Admin User",
  "email": "admin@acme.com",
  "password": "secure123",
  "custom_domain": "acme-docs.mycompany.com"
}
```

Example update to set custom domain:

```bash
PATCH /api/v1/company
{
  "company": {
    "custom_domain": "acme-docs.mycompany.com"
  }
}
```

### Production setup

To use custom domains in production:

1. Ensure your DNS records point the custom domain to your application server
2. Configure your SSL/TLS certificate to support the custom domain (wildcard or SAN)
3. Companies can set their custom domain via the admin API

The domain resolution happens at request time via the `Company.find_by_host(request.host)` method.

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
