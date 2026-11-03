# Shelfsight

Import your Goodreads library, see how you read, and get book suggestions you can trust.

- **Backend:** Rails 8 API-only, PostgreSQL, Solid Queue (`backend/`)
- **Frontend:** Vue 3 + Vite + TypeScript, Pinia, Tailwind, Chart.js (`frontend/`)

## Setup

Requirements: Ruby 3.4.10 (rbenv), Node 22.18+ or 24.12+, PostgreSQL running locally.

```sh
cd backend && bundle install && bin/rails db:prepare && cd ..
cd frontend && npm install && cd ..
bin/dev
```

- API: http://localhost:3000/api/v1/health
- App: http://localhost:5173

## Getting your Goodreads data

Goodreads no longer offers a public API. Shelfsight uses:
1. **CSV export:** Goodreads → My Books → Import and export → Export Library. Upload the file in the app.
2. **RSS sync (optional):** if your profile is public, enter your Goodreads user ID for automatic incremental syncs.

## Roadmap
1. ✅ Scaffold (monorepo, Rails API, Vue app, RSpec/Vitest, CORS, `bin/dev`)
2. Auth: accounts with token sessions
3. CSV import: parser, idempotent upsert, background job, upload UI
4. Enrichment + insights: Open Library metadata, reading stats, dashboard charts
5. Recommendations: Open Library candidates ranked and explained by Claude
6. RSS sync: recurring incremental imports
7. Polish: rate limiting, empty/error states, deployment
