// Keep in sync with backend serializers (backend/app/serializers).

export interface ApiErrorBody {
  error: {
    code: string
    message: string
    details: Record<string, unknown>
  }
}

export interface HealthResponse {
  status: 'ok'
  time: string
}

export interface User {
  id: number
  email_address: string
  created_at: string
}

export interface Credentials {
  email_address: string
  password: string
}

export interface AuthResponse {
  token: string
  user: User
}

export interface MeStats {
  books: number
  last_import_at: string | null
}

export interface MeResponse {
  user: User
  stats: MeStats
}
