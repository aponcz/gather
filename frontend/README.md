# ProText Gather React Frontend

React/Vite frontend for the Rails API backend generated for the FileInvite-style document collection application.

## Features

- Admin registration/login using JWT
- Admin dashboard with invite status tracking
- Contact creation/listing
- Invite creation with requested document checklist
- Invite detail, send action, portal link, file review, approve/reject, download URL
- Client magic-link flow
- Client invite portal with direct-to-S3/MinIO presigned uploads

## Requirements

- Node.js 20+
- Rails backend running on `http://localhost:3000`
- Backend CORS enabled for `http://localhost:5173`

## Setup

```bash
cp .env.example .env
npm install
npm run dev
```

Open:

```text
http://localhost:5173
```

## Environment

```env
VITE_API_BASE_URL=http://localhost:3000
```

## Typical local workflow

1. Start the Rails backend and dependencies.
2. Start this React app with `npm run dev`.
3. Register an admin organization or sign in.
4. Create a contact.
5. Create an invite with requested documents.
6. Send the invite.
7. Open the Client Portal page.
8. Request a magic link for the contact email. In local development, the backend returns the magic token directly.
9. Create the client session.
10. Open the invite's client portal route and upload files.
11. Return to the admin invite detail page to approve/reject uploaded files.

## Important backend CORS note

If browser requests are blocked by CORS, add the `rack-cors` gem to the Rails backend and configure development CORS like this:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:5173'
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

## File upload note

The client upload flow follows the backend API:

1. `POST /api/v1/client/request-items/:id/upload-url`
2. `PUT` file bytes to the returned presigned MinIO/S3 URL
3. `POST /api/v1/client/request-items/:id/complete-upload`

For MinIO local development, confirm the Rails backend returns presigned URLs that your browser can reach, usually `http://localhost:9000`.
