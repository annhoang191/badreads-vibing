import type { Recommendation, RecommendationBatch, RecommendationQuota } from '@/types/api'

export function recommendation(id: number, over: Partial<Recommendation> = {}): Recommendation {
  return {
    id,
    position: id,
    score: 92,
    status: 'new',
    reason: `Because you loved Book ${id}.`,
    book: {
      id: id * 10,
      title: `Rec ${id}`,
      author: `Author ${id}`,
      year: 2001,
      num_pages: 320,
      cover_url: `https://example.com/rec${id}.jpg`,
      open_library_url: `https://openlibrary.org/works/OL${id}W`,
    },
    ...over,
  }
}

export function batch(over: Partial<RecommendationBatch> = {}): RecommendationBatch {
  return {
    id: 1,
    status: 'completed',
    ranked_by: 'agent',
    error_message: null,
    created_at: '2026-11-03T10:00:00Z',
    recommendations: Array.from({ length: 10 }, (_, i) => recommendation(i + 1)),
    ...over,
  }
}

export function quota(over: Partial<RecommendationQuota> = {}): RecommendationQuota {
  return { limit: 5, remaining: 4, resets_at: null, ...over }
}
