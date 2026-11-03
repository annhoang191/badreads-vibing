import type { ApiErrorBody } from '@/types/api'

const BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1'

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details: Record<string, unknown> = {},
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

let authToken: string | null = null

export function setAuthToken(token: string | null) {
  authToken = token
}

type UnauthorizedHandler = () => void
let unauthorizedHandler: UnauthorizedHandler | null = null

/** Registers a callback invoked on any 401 (except a failed login attempt). */
export function onUnauthorized(handler: UnauthorizedHandler | null) {
  unauthorizedHandler = handler
}

export async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers)
  headers.set('Accept', 'application/json')
  if (init.body && !(init.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json')
  }
  if (authToken) headers.set('Authorization', `Bearer ${authToken}`)

  const response = await fetch(`${BASE_URL}${path}`, { ...init, headers })

  if (response.status === 204) return undefined as T

  const body = await response.json().catch(() => null)

  if (!response.ok) {
    const isLogin = path === '/session' && init.method === 'POST'
    if (response.status === 401 && !isLogin) unauthorizedHandler?.()
    const err = (body as ApiErrorBody | null)?.error
    throw new ApiError(
      response.status,
      err?.code ?? 'unknown_error',
      err?.message ?? response.statusText,
      err?.details,
    )
  }

  return body as T
}
