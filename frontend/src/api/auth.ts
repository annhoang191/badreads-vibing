import { request } from './client'
import type { AuthResponse, Credentials, MeResponse } from '@/types/api'

const post = <T>(path: string, body: unknown) =>
  request<T>(path, { method: 'POST', body: JSON.stringify(body) })

export const register = (credentials: Credentials) =>
  post<AuthResponse>('/registrations', credentials)

export const login = (credentials: Credentials) => post<AuthResponse>('/session', credentials)

export const logout = () => request<void>('/session', { method: 'DELETE' })

export const me = () => request<MeResponse>('/me')
