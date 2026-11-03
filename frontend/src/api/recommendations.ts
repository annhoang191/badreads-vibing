import { request } from './client'
import type { RecommendationBatch, RecommendationQuota } from '@/types/api'

export interface RecommendationsState {
  batch: RecommendationBatch | null
  quota: RecommendationQuota
}

export const latest = () => request<RecommendationsState>('/recommendations')

export const generate = () =>
  request<{ batch: RecommendationBatch; quota: RecommendationQuota }>('/recommendations/generate', {
    method: 'POST',
  })

export const getBatch = (id: number) =>
  request<{ batch: RecommendationBatch }>(`/recommendation_batches/${id}`).then((r) => r.batch)
