import { request } from './client'
import type { PageMeta, UserBook } from '@/types/api'

export interface BookListParams {
  shelf?: string
  tag?: string
  rating?: string
  year?: string
  q?: string
  sort?: string
  page?: number
  per_page?: number
}

export function list(params: BookListParams = {}) {
  const qs = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== '') qs.set(key, String(value))
  }
  const query = qs.toString()
  return request<{ data: UserBook[]; meta: PageMeta }>(`/books${query ? `?${query}` : ''}`)
}
