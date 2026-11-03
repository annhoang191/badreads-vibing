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
