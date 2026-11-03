import { request } from './client'
import type { InsightsSnapshot } from '@/types/api'

/** Resolves to null when insights have not been computed yet (204). */
export const get = () =>
  request<{ insights: InsightsSnapshot } | undefined>('/insights').then((r) => r?.insights ?? null)

export const refresh = () => request<unknown>('/insights/refresh', { method: 'POST' })
