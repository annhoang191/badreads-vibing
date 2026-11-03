import type { InsightsSnapshot } from '@/types/api'

export function snapshot(over: Partial<InsightsSnapshot> = {}): InsightsSnapshot {
  return {
    version: 1,
    computed_at: '2026-11-01T10:00:00Z',
    coverage: { read_total: 240, dated: 212, with_pages: 230, rated: 200, enriched: 150 },
    metrics: {
      totals: { read: 240, currently_reading: 2, to_read: 40, pages_read: 70000 },
      books_per_year: [
        { year: 2024, count: 30 },
        { year: 2025, count: 40 },
        { year: null, count: 28 },
      ],
      books_per_month: [
        { month: '2026-09', count: 2 },
        { month: '2026-10', count: 3 },
      ],
      pages_per_year: [{ year: 2025, pages: 12000 }],
      rating_distribution: { '1': 1, '2': 2, '3': 30, '4': 100, '5': 67, unrated: 40 },
      average_rating: 4.12,
      rating_vs_crowd: {
        mean_diff: 0.31,
        higher: [
          { book_id: 1, title: 'High One', author: 'A', my_rating: 5, avg_rating: 3.2, diff: 1.8 },
        ],
        lower: [],
      },
      top_authors: [{ author: 'Ursula Le Guin', count: 9, mean_rating: 4.5 }],
      top_subjects: [{ subject: 'science fiction', weight: 0.9, count: 20 }],
      length_buckets: {
        under_200: 10,
        from_200_to_349: 100,
        from_350_to_499: 80,
        over_500: 40,
        unknown: 10,
      },
      publication_decades: [
        { decade: 1990, count: 20 },
        { decade: null, count: 5 },
      ],
      pace: { books_per_month_12m: 3.5, best_month: { month: '2026-03', count: 8 } },
      rereads: [],
      tbr: { size: 40, oldest: [], median_age_days: 300 },
    },
    ...over,
  }
}
