# Shelfsight

Analyzes a user's Goodreads reading history and suggests books to read next.
Monorepo: `backend/` (Rails 8 API-only) + `frontend/` (Vue 3 + Vite + TS).

## Important constraints
- **There is no Goodreads API** (it was shut down in 2020). Data comes from:
  1. The user's CSV export (primary, full history). See `Goodreads::CsvParser`.
  2. Public RSS shelf feeds (`/review/list_rss/:user_id?shelf=`) for incremental sync.
  Do NOT add HTML scraping of goodreads.com.
- Book metadata comes from the Open Library API (no key). Respect rate limits: batch and throttle in jobs, never in a request cycle.
- Recommendations: the LLM may only rank and explain candidates we supply. It must never
  produce free-form book titles. Validate that every returned `candidate_id` exists.
- Never send user emails or passwords to the LLM. Send only the aggregated reading profile and candidate metadata.

## Commands
Run from the repo root unless noted.
- `bin/dev`: start Rails (:3000), Solid Queue (`bin/jobs`), and Vite (:5173) via foreman
- Backend (`cd backend`):
  - `bin/rails db:prepare` (creates `shelfsight_development` + `shelfsight_development_queue`)
  - `bundle exec rspec` / `bundle exec rspec spec/path_spec.rb:42`
  - `bin/rubocop -a`
- Frontend (`cd frontend`):
  - `npm run dev` / `npm run build`
  - `npx vitest run` (CI-style; `npm run test:unit` runs in watch mode)
  - `npm run lint` / `npm run type-check`

## Backend conventions
- Ruby 3.4.10 (`.ruby-version` at repo root), Rails 8.0, PostgreSQL. Jobs use Solid Queue
  (in development too, with a separate queue DB), cache uses Solid Cache. No Redis.
- `json` is pinned to `~> 2.10` because json 3.x breaks ActiveSupport 8.0's encoder
  (`unknown keyword: quirks_mode`). Don't bump it until Rails supports json 3.
- All endpoints live under `Api::V1::` in `app/controllers/api/v1/` and inherit from
  `Api::V1::BaseController`. JSON only.
- Business logic goes in `app/services/<Namespace>/<Name>.rb` with a single public `#call`.
  Controllers stay thin: params → service → serializer.
- Serializers use Alba (`app/serializers`). Never `render json: model` directly.
- Error shape: `{ error: { code:, message:, details: } }`. Raise `ApiError` subclasses
  (`app/errors/api_error.rb`); they're rescued in `Api::V1::BaseController`.
- Auth: Rails 8 authentication generator with `Authorization: Bearer <session.token>`.
  Every controller requires auth unless it explicitly calls `allow_unauthenticated_access`.
- Anything slow (imports, enrichment, LLM calls) runs in a job. The endpoint returns 202 plus a resource the client can poll.
- Imports must be idempotent: upsert on `books.goodreads_book_id` and `user_books(user_id, book_id)`.
- Store secrets in Rails credentials (`anthropic.api_key`), never in ENV files committed to git.
- CORS origins come from `FRONTEND_ORIGINS` (default `http://localhost:5173`), see `config/initializers/cors.rb`.

## LLM usage
- Use the official `anthropic` gem, default model `claude-sonnet-5-5`. The model is set in `config/llm.yml`.
- Prompts live in `app/prompts/*.md.erb` and are versioned (`PROMPT_VERSION`). Bump the version when a prompt changes.
- Request JSON output and parse strictly. On a parse or validation failure, retry once, then mark the batch failed.
- Log token usage on `recommendation_batches`.

## Frontend conventions
- Vue 3 `<script setup lang="ts">`, Composition API only. No Options API.
- State lives in Pinia stores in `src/stores/`. API calls go only through `src/api/`
  (`request()` in `src/api/client.ts` adds the bearer token and throws `ApiError`).
  Components never call `fetch` directly.
- API base URL comes from `VITE_API_URL` (`frontend/.env.development`).
- Styling uses Tailwind v4 utility classes (`@import 'tailwindcss'` in `src/style.css`).
  Charts use `vue-chartjs` wrappers in `src/components/charts/`.
- API types live in `src/types/api.ts`. Keep them in sync with the serializers when you change a payload.
- oxlint requires typed mocks in tests: `vi.fn<typeof fetch>()`, not `vi.fn()`.

## Testing
- Backend: RSpec + FactoryBot + Shoulda. External HTTP (Open Library, RSS, Anthropic) must be
  stubbed with WebMock/VCR (`spec/support/webmock_vcr.rb`). Tests never hit the network.
  Request specs cover every endpoint.
- Sample Goodreads export fixture: `backend/spec/fixtures/files/goodreads_export.csv`.
- Frontend: Vitest + Vue Test Utils for stores and components that contain logic (`src/__tests__/`).
- Before you call a task done, run the relevant test suite and linter and confirm they pass.

## Workflow
- Make small, focused changes. Add a migration and a spec with every model change.
- Don't add new gems or npm packages without saying why in the PR or summary.
- Product requirements, data model, API contract, and algorithms: `SPEC.md` (source of truth for *what*). Roadmap: `README.md`.

## Git workflow
- **No `Co-Authored-By` trailer in commit messages.**
- **Commit as you go:** one logical step per commit (e.g. "add contract tests",
  "fix lastEventId query param"), never one lump at the end.
- **Message format:** imperative subject ≤ 72 chars, optionally prefixed with the
  area (`api:`, `web:`, `docs:`, `agent:`). Add a body when the *why* isn't obvious.
  `git status` for stray files first.
- **Don't push or open the PR** unless the user asks.
