import type { Import, UserBook } from '@/types/api'

export const baseImport: Import = {
  id: 1,
  source: 'csv',
  status: 'pending',
  filename: 'goodreads.csv',
  stats: null,
  error_message: null,
  started_at: null,
  finished_at: null,
  created_at: '2026-01-01T00:00:00Z',
}

export function userBook(id: number, over: Partial<UserBook> = {}): UserBook {
  return {
    id,
    exclusive_shelf: 'read',
    shelves: [],
    my_rating: 4,
    date_read: '2025-03-01',
    date_added: '2025-01-01',
    read_count: 1,
    book: {
      id,
      title: `Book ${id}`,
      author: `Author ${id}`,
      num_pages: 300,
      year_published: 2000,
      avg_rating: 4.1,
      cover_url: `https://example.com/${id}.jpg`,
    },
    ...over,
  }
}
