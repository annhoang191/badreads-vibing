import { request } from './client'
import type { HealthResponse } from '@/types/api'

export const getHealth = () => request<HealthResponse>('/health')
