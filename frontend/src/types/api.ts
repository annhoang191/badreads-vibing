// Keep in sync with backend serializers (backend/app/serializers).

export interface ApiErrorBody {
  error: {
    code: string
    message: string
    details: Record<string, unknown>
  }
}

export interface HealthResponse {
  status: 'ok'
  time: string
}

export interface User {
  id: number
  email_address: string
  created_at: string
}

export interface Credentials {
  email_address: string
  password: string
}

export interface AuthResponse {
  token: string
  user: User
}

export interface MeStats {
  books: number
  last_import_at: string | null
}

export interface MeResponse {
  user: User
  stats: MeStats
}

export type ImportStatus = 'pending' | 'processing' | 'completed' | 'failed'

export interface ImportStats {
  rows_total?: number
  books_created?: number
  books_updated?: number
  shelvings_created?: number
  shelvings_updated?: number
  rows_skipped?: number
  missing_from_source?: number
  errors?: { row: number; reason: string }[]
  warnings?: string[]
}

export interface Import {
  id: number
  source: 'csv' | 'rss'
  status: ImportStatus
  filename: string | null
  stats: ImportStats | null
  error_message: string | null
  started_at: string | null
  finished_at: string | null
  created_at: string
}

export type Shelf = 'read' | 'currently-reading' | 'to-read'

export interface BookSummary {
  id: number
  title: string
  author: string
  num_pages: number | null
  year_published: number | null
  avg_rating: number | null
  cover_url: string | null
}

export interface UserBook {
  id: number
  exclusive_shelf: Shelf
  shelves: string[]
  my_rating: number | null
  date_read: string | null
  date_added: string | null
  read_count: number
  book: BookSummary
}

export interface PageMeta {
  page: number
  per_page: number
  total: number
  total_pages: number
}

export type BookSort = 'date_read' | 'date_added' | 'title' | 'my_rating' | 'num_pages'

export interface BookFilters {
  shelf: Shelf | ''
  tag: string
  rating: '' | '1' | '2' | '3' | '4' | '5' | 'unrated'
  year: string
  q: string
  sort: BookSort
  page: number
}

export interface BookDiff {
  book_id: number
  title: string
  author: string
  my_rating: number
  avg_rating: number
  diff: number
}

export interface InsightsSnapshot {
  version: 1
  computed_at: string
  coverage: {
    read_total: number
    dated: number
    with_pages: number
    rated: number
    enriched: number
  }
  metrics: {
    totals: { read: number; currently_reading: number; to_read: number; pages_read: number }
    books_per_year: { year: number | null; count: number }[] // ascending; null = undated, last
    books_per_month: { month: string; count: number }[] // last 24 months incl. current, zero-filled
    pages_per_year: { year: number; pages: number }[] // ascending, dated books only
    rating_distribution: {
      '1': number
      '2': number
      '3': number
      '4': number
      '5': number
      unrated: number
    }
    average_rating: number | null // 2 decimals
    rating_vs_crowd: {
      mean_diff: number | null // mean(my_rating - avg_rating), 2 decimals
      higher: BookDiff[] // up to 5, largest positive diff first
      lower: BookDiff[] // up to 5, largest negative diff first
    }
    top_authors: { author: string; count: number; mean_rating: number | null }[] // up to 10
    top_subjects: { subject: string; weight: number; count: number }[] // up to 15, weight 0..1
    length_buckets: {
      under_200: number
      from_200_to_349: number
      from_350_to_499: number
      over_500: number
      unknown: number
    }
    publication_decades: { decade: number | null; count: number }[] // e.g. 1960; null = unknown, last
    pace: { books_per_month_12m: number; best_month: { month: string; count: number } | null }
    rereads: { book_id: number; title: string; author: string; read_count: number }[]
    tbr: {
      size: number
      oldest: { book_id: number; title: string; author: string; date_added: string | null }[]
      median_age_days: number | null
    }
  }
}

export interface GoodreadsProfile {
  goodreads_user_id: string
  rss_enabled: boolean
  last_synced_at: string | null
  last_error: string | null
  consecutive_failures: number
}

export type BatchStatus = 'pending' | 'processing' | 'completed' | 'failed'

export interface RecommendedBook {
  id: number
  title: string
  author: string
  year: number | null
  num_pages: number | null
  cover_url: string | null
  open_library_url: string | null
}

export interface Recommendation {
  id: number
  position: number
  score: number // 0..100
  status: 'new' | 'saved' | 'dismissed'
  reason: string
  book: RecommendedBook
}

export interface RecommendationBatch {
  id: number
  status: BatchStatus
  ranked_by: 'agent' | 'heuristic' | null
  error_message: string | null
  created_at: string
  recommendations: Recommendation[] // empty until completed
}

export interface RecommendationQuota {
  limit: number
  remaining: number
  resets_at: string | null
}
