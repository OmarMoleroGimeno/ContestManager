import { apiClient } from './apiClient'
// import type { FetchOptions } from 'ofetch'

/**
 * Clase base para la capa Repository.
 * Todos los sub-módulos deberán heredar de esta clase para tener acceso
 * a utilidades HTTP preconfiguradas e internamente tipadas.
 */
export class ApiService {
  protected client = apiClient

  protected async get<T>(url: string, options?: any) {
    return this.client<T>(url, { ...options, method: 'GET' })
  }

  protected async post<T>(url: string, body?: any, options?: any) {
    return this.client<T>(url, { ...options, method: 'POST', body })
  }

  protected async put<T>(url: string, body?: any, options?: any) {
    return this.client<T>(url, { ...options, method: 'PUT', body })
  }

  protected async patch<T>(url: string, body?: any, options?: any) {
    return this.client<T>(url, { ...options, method: 'PATCH', body })
  }

  protected async delete<T>(url: string, options?: any) {
    return this.client<T>(url, { ...options, method: 'DELETE' })
  }
}
