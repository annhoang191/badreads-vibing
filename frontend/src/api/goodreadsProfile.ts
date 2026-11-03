import { request } from './client'
import type { GoodreadsProfile, Import } from '@/types/api'

/** Resolves to null when no profile is saved (204). */
export const get = () =>
  request<{ profile: GoodreadsProfile } | undefined>('/goodreads_profile').then(
    (r) => r?.profile ?? null,
  )

export const update = (goodreadsUserId: string, rssEnabled: boolean) =>
  request<{ profile: GoodreadsProfile }>('/goodreads_profile', {
    method: 'PUT',
    body: JSON.stringify({ goodreads_user_id: goodreadsUserId, rss_enabled: rssEnabled }),
  }).then((r) => r.profile)

export const sync = () =>
  request<{ import: Import }>('/goodreads_profile/sync', { method: 'POST' }).then((r) => r.import)
