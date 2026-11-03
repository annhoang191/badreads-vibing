import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApiError, onUnauthorized, request, setAuthToken } from '@/api/client'

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
    onUnauthorized(null)
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

  it('calls the unauthorized handler on 401 but not for a failed login', async () => {
    const handler = vi.fn<() => void>()
    onUnauthorized(handler)
    const body = { error: { code: 'unauthorized', message: 'no', details: {} } }

    mockFetch(401, body)
    await expect(request('/me')).rejects.toMatchObject({ status: 401 })
    expect(handler).toHaveBeenCalledTimes(1)

    mockFetch(401, { error: { ...body.error, code: 'invalid_credentials' } })
    await expect(request('/session', { method: 'POST', body: '{}' })).rejects.toMatchObject({
      code: 'invalid_credentials',
    })
    expect(handler).toHaveBeenCalledTimes(1)
  })
})
