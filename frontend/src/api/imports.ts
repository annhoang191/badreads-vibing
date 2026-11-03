import { request } from './client'
import type { Import } from '@/types/api'

export function create(file: File) {
  const body = new FormData()
  body.append('file', file)
  return request<{ import: Import }>('/imports', { method: 'POST', body }).then((r) => r.import)
}

export const list = () => request<{ data: Import[] }>('/imports').then((r) => r.data)

export const get = (id: number) =>
  request<{ import: Import }>(`/imports/${id}`).then((r) => r.import)
