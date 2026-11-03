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
