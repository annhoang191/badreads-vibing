---
name: rails-patterns
description: Design patterns for Shelfsight's Rails 8 API (backend/). Use before writing or changing any Ruby under backend/ — controllers, models, services, queries, serializers, jobs, API clients, LLM agents — to pick the right pattern and location, and when reviewing backend code for structure.
---

# Rails patterns for Shelfsight

The backend is a JSON API: `Api::V1::*` controllers → domain objects → Postgres, plus background jobs and external HTTP (Open Library, Goodreads RSS, Anthropic). Each kind of code has **one** home. Pick it from the table, then follow the section below.

`SPEC.md` defines *what* to build. This skill defines *where code goes and what shape it takes*.

## Decision table

| I'm writing… | Pattern | Put it in | Base / tool |
|---|---|---|---|
| An endpoint | **Thin controller** | `app/controllers/api/v1/` | `Api::V1::BaseController` ✅ |
| A business operation (create/update across models, side effects) | **Service object** | `app/services/<domain>/<verb_noun>.rb` | `ApplicationService` ✅ |
| A non-trivial read: filters, sorts, joins, aggregates | **Query object** | `app/queries/<domain>/<name>_query.rb` | `ApplicationQuery` ✅ |
| JSON output | **Serializer** | `app/serializers/<model>_serializer.rb` | `ApplicationSerializer` ✅ (Alba) |
| An expected failure the client must see | **Typed error** | `app/errors/api_error.rb` | `ApiError::*` ✅ |
| User input that isn't one model (an upload, multi-model) | **Form object** | `app/forms/<domain>/<name>.rb` | `ActiveModel::Model` |
| A call to an external HTTP API | **Adapter (client)** | `app/clients/<vendor>/client.rb` | Faraday |
| Immutable data passed between layers | **Value object** | next to its producer | `Data.define` |
| Slow, retryable, or scheduled work | **Job** | `app/jobs/` | `ApplicationJob` ✅ |
| Behaviour chosen by config (e.g. model tier) | **Strategy / registry** | `app/lib/<area>/` | plain Ruby + YAML |
| An LLM tool or subagent | **Command object** | `app/agents/` | `Anthropic::BaseTool` |

✅ = exists in the repo today. Anything else gets created the first time a milestone needs it, following this skill.

## Controllers: thin
Params → form/service/query → serializer. Nothing else.
```ruby
def index
  books = Books::LibraryQuery.call(current_user.user_books, library_params)
  render json: UserBookSerializer.new(paginate(books)).serialize
end
```
- No `.where` chains, no business rules, no `rescue` (errors bubble up to `BaseController`).
- Strong params live in a private `*_params` method.
- Slow work returns `202` and a pollable resource: `render json: ImportSerializer.new(import).serialize, status: :accepted`.

## Models: data and invariants only
Allowed: associations, validations, `enum`, scopes, small predicates (`read?`).
- Enums are string-backed and validated: `enum :status, { pending: "pending", completed: "completed" }, validate: true`.
- **No side-effecting callbacks.** No HTTP calls, job enqueues or other models' writes in `after_*`. Put them in the service that performs the operation. Callbacks only normalize the model's own attributes (`before_validation { self.email_address = email_address.downcase }`).
- Concerns only for behaviour genuinely shared by 2+ models.

## Service objects
```ruby
module Imports
  class Upserter < ApplicationService
    def initialize(user:, rows:)
      @user = user
      @rows = rows
    end

    def call
      ActiveRecord::Base.transaction { ... }
      stats # return a plain value, not self
    end
  end
end
# Imports::Upserter.call(user:, rows:)
```
- Name it verb + noun or role (`Upserter`, `Pipeline`, `GenerateBatch`). One public method: `#call`. Keyword arguments.
- **Expected failures raise `ApiError` subclasses.** No `Result`/monads, no `success?` flags. Add a new subclass to `api_error.rb` when a new error `code` is needed.
- A service may call other services or clients, but keep it to two levels at most. A deeper chain means you need a `Pipeline` service that orchestrates explicitly.
- Wrap multi-row writes in one transaction. Use `upsert_all` for imports (FR-I4 idempotency).

## Query objects
```ruby
module Books
  class LibraryQuery < ApplicationQuery
    SORTS = { "date_read" => { date_read: :desc }, "title" => { title: :asc } }.freeze

    def call
      scope = relation.joins(:book)
      scope = scope.where(exclusive_shelf: params[:shelf]) if params[:shelf].present?
      scope.order(SORTS.fetch(params[:sort], SORTS["date_read"]))
    end
  end
end
```
- Always return a **relation**, never an array, so callers can paginate (`pagy`) and chain.
- Whitelist sort and filter values with constants. Never interpolate params into SQL.
- Scope by the current user in the controller (pass `current_user.user_books`), not inside the query.

## Serializers (Alba)
```ruby
class ImportSerializer < ApplicationSerializer
  attributes :id, :source, :status, :stats, :started_at, :finished_at
end
```
- Never `render json: model` or `as_json`. Each payload change must be matched in `frontend/src/types/api.ts`.
- Nest with `one :book, resource: BookSerializer`. Keep serializers free of queries; preload in the query object.

## Form objects
Use one when input doesn't map to a single model, such as validating a CSV upload before creating an `Import` (FR-I1/FR-I2):
```ruby
module Imports
  class CsvUpload
    include ActiveModel::Model
    attr_accessor :file
    validates :file, presence: true
    validate :size_and_header
  end
end
```
In the controller: `form.validate!` raises `ActiveModel::ValidationError`. Map it in `BaseController` to `422`, or raise `ApiError::Unprocessable` with `details: form.errors.to_hash`.

## Adapters (external API clients)
- One class per vendor. It owns the Faraday connection, timeouts (connect 5s, read 15s), retries, the `User-Agent`, and rate limiting.
- Return **value objects**, never raw JSON hashes, so the rest of the app doesn't depend on the vendor's format.
- Never call a client from a request cycle when it's slow or rate-limited. Go through a job (SPEC §3.4).
- Specs use WebMock/VCR. Tests never touch the network.

## Value objects
```ruby
CsvRow = Data.define(:goodreads_book_id, :title, :author, :isbn13, :my_rating, :date_read)
```
Immutable, compared by value. Use them for parsed rows, profiles and API responses. Keep them small; add methods only for derived values.

## Jobs
```ruby
class ImportCsvJob < ApplicationJob
  queue_as :default
  def perform(import_id) = Imports::ProcessCsv.call(import: Import.find(import_id))
end
```
- Pass **IDs**, not records. Delegate to **one** service. Be idempotent, because Solid Queue may retry.
- Status transitions (`pending → processing → completed/failed`) happen in the service.

## Strategy / registry
Behaviour that varies by configuration goes in a small registry read from YAML, e.g. `Llm::Router.for(:rank_candidates)`, which returns the tier, model and effort from `config/llm.yml`. Callers never branch on model names.

## LLM agents (SPEC §4.4)
Each tool or subagent is one `Anthropic::BaseTool` subclass in `app/agents/` whose `#call` delegates to a service, query or client. The orchestrator is an agent class; the guardrails and output validation are plain Ruby around it. See the `LLM usage` section of `CLAUDE.md`.

## Anti-patterns
| Don't | Why |
|---|---|
| Fat models / god objects | Untestable, and callbacks fire in surprising places |
| Side effects in callbacks | Imports and tests trigger HTTP calls and jobs you didn't ask for |
| `Result` objects / `success?` booleans | We raise `ApiError`. Two error styles means bugs |
| Business logic or `.where` in controllers | Duplicated across endpoints; hard to test |
| Raw vendor hashes passed around | Every vendor format change ripples through the app |
| `render json: record` | Leaks columns; breaks the frontend types contract |
| Network calls in specs | Flaky; the WebMock config will block them anyway |

## Tests per layer
| Layer | Spec type | Notes |
|---|---|---|
| Controller | request spec (`spec/requests/api/v1/`) | Status, JSON shape, auth, error codes |
| Service / query | unit spec, real DB | FactoryBot; assert results, not internals |
| Serializer | unit spec | Exact keys (guards the frontend contract) |
| Client | unit spec + WebMock/VCR | Parsing, retries, error mapping |
| Job | unit spec | Only checks it delegates with the right args |

A full end-to-end example (the CSV import flow) is in `references/examples.md`.
