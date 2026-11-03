import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApiError, request, setAuthToken } from '@/api/client'

function mockFetch(status: number, body: unknown) {
  const fn = vi.fn<typeof fetch>().mockResolvedValue(
    new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    }),
  )
  vi.stubGlobal('fetch', fn)
  return fn
}

describe('api client', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    setAuthToken(null)
  })

  it('returns parsed JSON and sends the bearer token', async () => {
    const fetchMock = mockFetch(200, { status: 'ok' })
    setAuthToken('abc123')

    await expect(request('/health')).resolves.toEqual({ status: 'ok' })

    const headers = fetchMock.mock.calls[0]![1]!.headers as Headers
    expect(headers.get('Authorization')).toBe('Bearer abc123')
  })

  it('throws ApiError using the backend error shape', async () => {
    mockFetch(422, { error: { code: 'unprocessable', message: 'Validation failed', details: {} } })

    await expect(request('/things')).rejects.toMatchObject({
      name: 'ApiError',
      status: 422,
      code: 'unprocessable',
    } satisfies Partial<ApiError>)
  })
})
