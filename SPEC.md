# Shelfsight — Product & Technical Specification

> Status: **Draft v0.1** (2026-11-03) · Owner: Hoang Quynh Anh
> This document defines *what* Shelfsight does and the contracts between its parts.
> *How* we write code (conventions, commands) lives in `CLAUDE.md`. When they conflict, update one of them; don't let them drift.

---

## 1. Overview

Shelfsight imports a reader's Goodreads library, turns it into a clear picture of their reading habits, and recommends books they're likely to enjoy, each with a short explanation of *why*.

### 1.1 Goals
- **G1:** Getting your Goodreads data in is painless: one CSV upload, plus optional automatic syncs.
- **G2:** Insights are accurate and explainable. Every number traces back to the user's own data.
- **G3:** Recommendations are real, available books, never hallucinated, and each comes with a specific reason.
- **G4:** The user's data stays private. The LLM only sees what it needs.

### 1.2 Non-goals (v1)
- Scraping goodreads.com HTML, or writing anything back to Goodreads.
- Social features (friends, sharing, public profiles).
- Mobile apps (the web UI should still be responsive).
- Imports from other services (StoryGraph, LibraryThing); the design should leave room for them.
- Buying or borrowing links beyond a plain Open Library link.

### 1.3 Personas
- **The Tracker:** a few hundred books on Goodreads, curious about patterns ("Am I reading less? Do I rate harshly?").
- **The Stuck Reader:** finished a book they loved and wants the next one, with more nuance than "people also read".

---

## 2. User stories

| ID | As a… | I want to… | So that… |
|---|---|---|---|
| US1 | visitor | create an account with email + password | my library and insights persist |
| US2 | user | upload my Goodreads CSV export | my full history is imported |
| US3 | user | see import progress and a summary (added/updated/skipped) | I know it worked |
| US4 | user | connect my public Goodreads profile ID | new books sync automatically |
| US5 | user | browse and filter my library | I can check what was imported |
| US6 | user | see a dashboard of my reading stats | I understand my habits |
| US7 | user | generate a set of recommendations | I find my next book |
| US8 | user | see why each book was recommended | I can trust the suggestion |
| US9 | user | save or dismiss a recommendation | future suggestions get better and my list stays clean |
| US10 | user | delete my account and all my data | I stay in control of my data |

---

## 3. Functional requirements

### 3.1 Accounts & sessions (US1, US10)
- **FR-A1:** Register with email (unique, case-insensitive) and password (min 10 characters). Returns a session token.
- **FR-A2:** Log in returns `{ token, user }`. Log out destroys the current session only.
- **FR-A3:** Every API call except register, login, and health requires `Authorization: Bearer <token>`. A missing or invalid token returns `401 unauthorized`.
- **FR-A4:** Sessions expire after 30 days of inactivity.
- **FR-A5:** `DELETE /me` hard-deletes the user and every row they own (user_books, imports, insights, recommendations, sessions, profile). Shared `books` rows are kept.
- **FR-A6:** Login is rate-limited to 10 attempts per 3 minutes per IP.
- *Out of scope for v1:* password reset email, OAuth. Track as a follow-up.

### 3.2 CSV import (US2, US3)
- **FR-I1:** Accept a `.csv` upload of at most 10 MB. Anything else returns `422` with code `invalid_file`.
- **FR-I2:** Validate the header before queuing. It must contain at least `Book Id`, `Title`, `Author`, and `Exclusive Shelf`; otherwise return `422` with code `invalid_goodreads_export`.
- **FR-I3:** Create an `Import` (status `pending`), return `202`, and process it in `ImportCsvJob`.
- **FR-I4:** Processing is **idempotent**: re-uploading the same file changes nothing, and a newer export updates changed rows. Matching keys:
  - Book: `goodreads_book_id`.
  - Shelving: `(user_id, book_id)`.
- **FR-I5:** Books in the DB that are absent from a new CSV are **not** deleted in v1. They're counted as `missing_from_source` in the stats. (Open question Q2.)
- **FR-I6:** A bad row doesn't fail the import. Skip it, record `{row, reason}` (keep at most 50), and keep going. The import fails only on file-level errors.
- **FR-I7:** When the import completes, its stats are `{ rows_total, books_created, books_updated, shelvings_created, shelvings_updated, rows_skipped, missing_from_source, errors: [...] }`.
- **FR-I8:** A completed import queues `EnrichBooksJob` for unenriched books, followed by `ComputeInsightsJob`.
- **FR-I9:** One active (`pending` or `processing`) import per user at a time. A second request returns `409 import_in_progress`.

**Goodreads CSV column mapping**

| CSV column | Target | Normalization |
|---|---|---|
| Book Id | books.goodreads_book_id | integer |
| Title | books.title | strip; keep series suffix, e.g. "(Mistborn, #1)" |
| Author | books.author | strip |
| Additional Authors | books.additional_authors | split on `,` into array |
| ISBN / ISBN13 | books.isbn / isbn13 | strip the `="…"` wrapper; blank → nil |
| Average Rating | books.avg_rating | decimal(3,2) |
| Number of Pages | books.num_pages | integer; 0 or blank → nil |
| Year Published | books.year_published | integer |
| Original Publication Year | books.original_publication_year | integer; fallback for decade stats |
| My Rating | user_books.my_rating | 0 → nil (unrated) |
| Exclusive Shelf | user_books.exclusive_shelf | `read` / `currently-reading` / `to-read` |
| Bookshelves | user_books.shelves | split on `,`, strip |
| Date Read / Date Added | user_books.date_read / date_added | `YYYY/MM/DD` → date; blank → nil |
| Read Count | user_books.read_count | integer, default 0 |
| My Review | user_books.review | stored as is, **never sent to the LLM** |
| Private Notes, Spoiler, Owned Copies, Publisher, Binding, Bookshelves with positions | — | ignored in v1 |

### 3.3 RSS sync (US4)
- **FR-R1:** The user saves a Goodreads user ID: digits, or a profile URL from which we extract the digits. We validate it by fetching page 1 of the `read` shelf feed. A 404 or a private profile returns `422 profile_not_public`.
- **FR-R2:** `SyncRssJob` fetches the `read`, `currently-reading`, and `to-read` shelves, paginating until a page returns no new items or comes back empty. It upserts through the same `Imports::Upserter` as CSV and creates an `Import` with `source: rss`.
- **FR-R3:** Runs every 6 hours for profiles with `rss_enabled`. The user can trigger it manually (`POST /goodreads_profile/sync`), at most once every 10 minutes.
- **FR-R4:** RSS never overwrites richer CSV data with blanks: an RSS value only replaces a field when it is present.
- **FR-R5:** After 3 consecutive failures the job sets `rss_enabled = false` and stores `last_error`. The UI shows it.
- *To verify in milestone 6:* the exact RSS item fields and page size. Record the findings here.

### 3.4 Book enrichment (supports US6 and US7)
- **FR-E1:** For each book with `enriched_at IS NULL`, look it up on Open Library, in this order:
  1. `GET /isbn/{isbn13 || isbn}.json`, then follow the `works` key.
  2. Otherwise `GET /search.json?title=&author=&limit=1`.
- **FR-E2:** Store `open_library_work_key`, `subjects` (normalized, see §4.2), `cover_url` (`https://covers.openlibrary.org/b/id/{cover_id}-M.jpg`), and fill `num_pages` and `original_publication_year` if they're blank.
- **FR-E3:** Send at most 1 request per second, with an identifying `User-Agent: Shelfsight/0.1 (<contact email>)`. Retry 3 times with exponential backoff on 429/5xx.
- **FR-E4:** If nothing is found, set `enriched_at` with `enrichment_status: not_found` so we don't retry forever. Re-enrichment is a manual admin task.

### 3.5 Library browsing (US5)
- **FR-L1:** `GET /books` lists the user's books, paginated at 25 per page, max 100.
- **FR-L2:** Filters:
  - `shelf` (exclusive shelf) and `tag` (custom shelf)
  - `rating` (1–5 or `unrated`)
  - `year` (year read)
  - `q` (case-insensitive substring match on title or author)
- **FR-L3:** Sort by `date_read` (default, desc, nulls last), `date_added`, `title`, `my_rating`, or `num_pages`.

### 3.6 Insights (US6)
- **FR-N1:** Insights are computed by `Analytics::ReadingProfile`, stored as one JSON snapshot in `reading_insights`, and served from there. `POST /insights/refresh` recomputes asynchronously.
- **FR-N2:** Recompute automatically after every completed import or enrichment batch.
- **FR-N3:** Every metric defines what it does with missing data (see §4.1). The UI shows its coverage, e.g. "based on 212 of 240 read books with a date".

### 3.7 Recommendations (US7–US9)
- **FR-C1:** `POST /recommendations/generate` creates a `RecommendationBatch` (status `pending`), returns `202`, and runs `GenerateRecommendationsJob`.
- **FR-C2:** Requires at least **10 read books with a rating**. Below that, return `422 not_enough_data`.
- **FR-C3:** Limit: 5 batches per user per rolling 24 hours. Over the limit, return `429 rate_limited` with `retry_after`.
- **FR-C4:** A batch contains **10 recommendations**. Each one references a real `books` row and has a `score` (0–100) and a `reason` (1–3 sentences, ≤ 300 characters) that cites the user's own books or patterns.
- **FR-C5:** Never recommend a book the user has already shelved on any shelf, or one they dismissed before. Matching is by work key, or by normalized title + author.
- **FR-C6:** Saving or dismissing changes the recommendation's `status`. Dismissed books are excluded from future candidates. Saved books show in a "Saved" list.
- **FR-C7:** If the LLM fails (after 1 retry) or returns invalid output, use the heuristic fallback (§4.3) and mark the batch `ranked_by: heuristic`. The user still gets results.
- **FR-C8:** The algorithm is specified in §4.3.

---

## 4. Domain logic

### 4.1 Insight definitions
"Read books" means `exclusive_shelf = 'read'`.

| Metric | Definition | Missing-data rule |
|---|---|---|
| `totals` | Count of read, currently reading, and TBR books; total pages read | Pages: sum of non-null `num_pages`; report coverage |
| `books_per_year` | Read books grouped by `year(date_read)` | No `date_read` → counted in an `undated` bucket |
| `books_per_month` | Same, for the last 24 months | Same |
| `pages_per_year` | Sum of `num_pages` by year read | Skip null pages |
| `rating_distribution` | Count of read books by `my_rating` 1–5 | Unrated reported separately |
| `average_rating` | Mean `my_rating` over rated books | — |
| `rating_vs_crowd` | Mean of (`my_rating − avg_rating`), plus the 5 books where the gap is largest in each direction | Both values required |
| `top_authors` | Top 10 by read count; include the mean rating | — |
| `top_subjects` | Top 15 normalized subjects, weighted by rating (§4.2) | Unenriched books are excluded; report coverage |
| `length_buckets` | <200, 200–349, 350–499, 500+ pages | Null pages → `unknown` |
| `publication_decades` | Decade of `original_publication_year` ‖ `year_published` | Neither → `unknown` |
| `pace` | Mean books per month over the last 12 months; best month | Dated books only |
| `rereads` | Books with `read_count > 1` | — |
| `tbr` | TBR size, oldest 5 by `date_added`, median TBR age in days | — |

Snapshot format: `{ version: 1, computed_at, coverage: {...}, metrics: { <name>: ... } }`. Bump `version` whenever a metric's shape changes. The frontend type lives in `src/types/api.ts`.

### 4.2 Subject normalization
Open Library subjects are noisy. Normalization steps:
1. Lowercase and strip; drop text in parentheses; split on ` -- `.
2. Drop a denylist: `fiction`, `accessible book`, `protected daisy`, `in library`, `large type books`, `lending library`, `english language`, `nyt:*`, `new york times bestseller`, anything matching `^\d+$`, and anything containing `translations`. Keep the denylist in `config/subject_denylist.yml`.
3. Map synonyms through `config/subject_aliases.yml`, e.g. `sci-fi` → `science fiction`.
4. Keep at most 15 subjects per book.

**Subject affinity** for the user. For every read book with a rating, each of its subjects gets the weight `(my_rating − user_mean_rating) + 1`, floored at 0. Sum the weights per subject and normalize the top-ranked one to 1.0. This favors subjects the user rates *above their own average*, not just subjects they read a lot.

### 4.3 Recommendation algorithm

**Step 1: Profile.** Build it from insights: the top 8 subjects by affinity, the top 5 authors by mean rating (at least 2 books read), 5 "anchor" books (the most recent 5★ reads), 3 "anti-anchors" (1–2★ reads), and length and decade preferences.

**Step 2: Candidate generation (Open Library).** Target 60 candidates after filtering.
- For each top subject: `GET /subjects/{slug}.json?limit=30` (popular works in that subject).
- For each top author: their other works via `/search.json?author=…&sort=rating` (limit 10).
- Merge and dedupe by work key. Apply the exclusions from FR-C5. Drop works without a title, an author, or a cover.

**Step 3: Heuristic pre-score.** Each candidate gets a value from 0 to 1:
```
pre_score = 0.55 * subject_overlap      (sum of matched subject affinities, capped at 1)
          + 0.25 * author_affinity      (1 if a liked author, else 0)
          + 0.10 * popularity           (log-scaled OL edition count or rating count, normalized)
          + 0.10 * length/decade fit    (1 if within the user's dominant buckets)
```
Keep the top 40. On its own this ordering is the **fallback** ranking (FR-C7). Fallback reasons come from a template: "Shares *{subject}* and *{subject}* with books you rated highly, like *{anchor}*."

**Step 4: LLM ranking (Claude).**
- *Input:* the profile summary (stats, anchors and anti-anchors given as title + author + rating only) and 40 candidates as `{ id, title, author, year, subjects[≤8], pages }`. `id` is a short opaque reference like `c17`.
- *Instruction:* choose the 10 best fits, give each a score from 0–100 and a reason that refers to the user's actual books or patterns, prefer variety (≤ 2 per author, ≤ 4 that share a top subject), and never output an id that isn't in the list.
- *Output (strict JSON):* `{ "recommendations": [ { "id": "c17", "score": 92, "reason": "..." } ] }`
- *Validation:* exactly 10 unique, known ids; score is an int from 0–100; the reason is non-empty and ≤ 300 characters. One retry with the validation errors appended, then fall back to the heuristic.
- *Never sent:* email, user id, reviews, private notes, custom shelf names.
- Record `model`, `prompt_version`, `input_tokens`, `output_tokens`, `ranked_by` on the batch.

**Step 5: Persist.** Upsert candidate works into `books` (with `goodreads_book_id` nil, `source: open_library`), then create the `recommendations` rows.

---

## 5. Data model

All tables have `id` (bigint) and `created_at`/`updated_at`. FKs are indexed and use `on_delete: cascade` from `users` (FR-A5).

| Table | Columns (beyond the defaults) | Constraints / indexes |
|---|---|---|
| `users` | email_address (citext), password_digest | unique(email_address) |
| `sessions` | user_id, token, ip_address, user_agent, last_used_at | unique(token) |
| `goodreads_profiles` | user_id, goodreads_user_id, rss_enabled (bool), last_synced_at, consecutive_failures (int), last_error | unique(user_id) |
| `books` | source (`goodreads`/`open_library`), goodreads_book_id, isbn, isbn13, title, author, additional_authors (string[]), num_pages, year_published, original_publication_year, avg_rating (decimal 3,2), open_library_work_key, subjects (jsonb array), cover_url, enrichment_status, enriched_at | unique(goodreads_book_id) where not null; unique(open_library_work_key) where not null; index(isbn13) |
| `user_books` | user_id, book_id, exclusive_shelf, shelves (string[]), my_rating (1–5, null), date_read, date_added, read_count, review | unique(user_id, book_id); index(user_id, exclusive_shelf); check rating 1–5 |
| `imports` | user_id, source (`csv`/`rss`), status (`pending`/`processing`/`completed`/`failed`), filename, stats (jsonb), error_message, started_at, finished_at | index(user_id, created_at) |
| `reading_insights` | user_id, version, data (jsonb), computed_at | unique(user_id) |
| `recommendation_batches` | user_id, status (`pending`/`processing`/`completed`/`failed`), ranked_by (`llm`/`heuristic`), model, prompt_version, input_tokens, output_tokens, error_message | index(user_id, created_at) |
| `recommendations` | recommendation_batch_id, user_id, book_id, position (1–10), score, reason, status (`new`/`saved`/`dismissed`) | unique(batch_id, book_id); index(user_id, status) |

The CSV file itself is processed from a temporary Active Storage blob that is **deleted after processing**.

---

## 6. API contract (`/api/v1`)

- **Conventions:** JSON, snake_case keys, ISO-8601 timestamps.
- **Errors:** `{ "error": { "code", "message", "details" } }`.
- **Pagination:** `?page=&per_page=`, with a `meta: { page, per_page, total, total_pages }` object in the response.

| Method & path | Auth | Success | Notable errors |
|---|---|---|---|
| `GET /health` | – | 200 | |
| `POST /registrations` `{email_address, password}` | – | 201 `{token, user}` | 422 |
| `POST /session` `{email_address, password}` | – | 201 `{token, user}` | 401, 429 |
| `DELETE /session` | ✓ | 204 | |
| `GET /me` | ✓ | 200 `{user, stats: {books, last_import_at}}` | |
| `DELETE /me` | ✓ | 204 | |
| `POST /imports` (multipart `file`) | ✓ | 202 `{import}` | 409, 422 |
| `GET /imports` / `GET /imports/:id` | ✓ | 200 | 404 |
| `PUT /goodreads_profile` `{goodreads_user_id, rss_enabled}` | ✓ | 200 `{profile}` | 422 |
| `POST /goodreads_profile/sync` | ✓ | 202 `{import}` | 409, 429 |
| `GET /books?shelf=&tag=&rating=&year=&q=&sort=&page=` | ✓ | 200 `{data, meta}` | |
| `GET /insights` | ✓ | 200 `{insights}` · 204 if none yet | |
| `POST /insights/refresh` | ✓ | 202 | |
| `POST /recommendations/generate` | ✓ | 202 `{batch}` | 422, 429 |
| `GET /recommendation_batches/:id` | ✓ | 200 `{batch}` (for polling) | 404 |
| `GET /recommendations?status=new\|saved` | ✓ | 200 `{data, meta}`, latest batch first | |
| `PATCH /recommendations/:id` `{status}` | ✓ | 200 | 422 |

Example: `GET /imports/42`
```json
{
  "import": {
    "id": 42, "source": "csv", "status": "completed",
    "filename": "goodreads_library_export.csv",
    "stats": { "rows_total": 241, "books_created": 238, "books_updated": 0,
               "shelvings_created": 241, "shelvings_updated": 0,
               "rows_skipped": 3, "missing_from_source": 0,
               "errors": [{ "row": 118, "reason": "Missing Book Id" }] },
    "started_at": "2026-11-03T10:00:01Z", "finished_at": "2026-11-03T10:00:04Z"
  }
}
```

Example: a recommendation
```json
{
  "id": 901, "position": 1, "score": 92, "status": "new",
  "reason": "You rated The Left Hand of Darkness and Ancillary Justice 5★ — this shares their focus on gender and political anthropology.",
  "book": { "id": 5531, "title": "A Memory Called Empire", "author": "Arkady Martine",
            "year": 2019, "num_pages": 462, "cover_url": "https://covers.openlibrary.org/b/id/123-M.jpg",
            "open_library_url": "https://openlibrary.org/works/OL20622134W" }
}
```

---

## 7. Frontend

| Route | View | Notes |
|---|---|---|
| `/login`, `/register` | Auth forms | Redirect to `/` if already logged in |
| `/onboarding` | CSV upload with how-to-export instructions; optional RSS profile ID | Shown when the user has 0 books |
| `/` | Dashboard | Charts from §4.1; empty and "computing…" states; coverage notes |
| `/library` | Filterable, sortable table with cover thumbnails | Filters reflected in the query string |
| `/recommendations` | Card grid: cover, title, author, score, reason; Save / Dismiss; "Saved" tab; Generate button with remaining daily quota | Polls the batch every 2s while it's pending |
| `/settings` | RSS profile, sync status and last error, import history, delete account (with typed confirmation) | |

- The token is stored in `localStorage`, set on the API client at boot, and cleared on any 401 (then redirect to `/login`).
- Import and batch progress are polled every 2 seconds. Polling stops on a terminal status or after 5 minutes.
- Accessibility: every chart has a text or table alternative; WCAG AA contrast; usable with the keyboard alone.

---

## 8. Non-functional requirements

| Area | Requirement |
|---|---|
| Performance | Read API endpoints p95 < 300 ms. A 1,000-row CSV imports in < 30 s, excluding enrichment. Recommendation batch < 60 s at p95. |
| Scale (v1) | ≤ 1,000 users and ≤ 10,000 books per user. A single Postgres; no sharding or caching beyond Solid Cache. |
| Reliability | Jobs are idempotent and safe to retry. External HTTP has timeouts (connect 5 s, read 15 s). |
| Security | bcrypt passwords; session tokens are random 32+ bytes; HTTPS only in production; CORS limited to `FRONTEND_ORIGINS`; params whitelisted; uploads validated by content, not just extension; Brakeman clean. |
| Privacy | LLM payload limited as in §4.3. No third-party analytics in v1. Account deletion is complete (FR-A5). |
| Cost | LLM spend tracked per batch. Target < $0.05 per batch. Alert if the daily total exceeds a configured cap. |
| Observability | Structured logs for every job (start, finish, duration, counts). Failed jobs visible in the Solid Queue tables. |
| Testing | Request specs for every endpoint; unit specs for the parser, upserter, analytics, and ranker validation; external HTTP stubbed; frontend store and component tests for logic. |

---

## 9. Milestones & acceptance criteria

| # | Milestone | Done when… |
|---|---|---|
| 1 | Scaffold | ✅ Both apps boot via `bin/dev`; health check passes with CORS; test suites and linters are green |
| 2 | Auth | A user can register, log in, and log out from the UI; protected routes return 401 without a token; `DELETE /me` works |
| 3 | CSV import | Uploading a real export shows progress, then stats; re-uploading is a no-op; the library page lists the books |
| 4 | Enrichment + insights | Most books with ISBNs get subjects and covers; the dashboard renders every §4.1 metric with coverage notes |
| 5 | Recommendations | 10 recommendations with reasons; none already shelved or dismissed; the fallback works when the LLM is stubbed to fail |
| 6 | RSS sync | Connecting a public profile syncs new shelvings without duplicates; the recurring job runs; failures surface in Settings |
| 7 | Polish | Rate limits in place; every view has empty, loading, and error states; deployment documented; Brakeman clean |

---

## 10. Open questions

- **Q1. Hosting:** Render or Fly.io, or Kamal on a VPS? This affects how Solid Queue runs (a separate worker vs. the Puma plugin).
- **Q2. Rows deleted from Goodreads:** should a fresh CSV remove books that aren't in it anymore? Proposal: offer a "full replace" checkbox on upload.
- **Q3. Cold start:** users with fewer than 10 rated books. Offer a short "pick 5 books you loved" flow?
- **Q4. Saved recommendations:** export them as a CSV the user can import back into Goodreads as a "to-read" shelf?
- **Q5. Password reset:** it needs email delivery (SMTP provider). Is it in v1 or v1.1?
- **Q6. Re-enrichment:** how often should we refresh Open Library metadata, if ever?
