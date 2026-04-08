// Rely on Nuxt auto-imported global $fetch for SSR compatibility

/**
 * Instancia del cliente HTTP basado en $fetch de Nuxt.
 * Totalmente compatible con SSR, y permite inyectar interceptores centralizados.
 */
export const apiClient = $fetch.create({
  // Interceptor antes de enviar (Útil para Headers o Tokens)
  onRequest({ request, options }) {
    // Ejemplo:
    // options.headers = new Headers(options.headers || {})
    // options.headers.set('Authorization', `Bearer token`)
  },
  
  // Interceptor global ante errores 
  onResponseError({ request, response, options }) {
    console.error(`[API Error ${response.status}] a ${request.toString()}`, response._data)
    
    // Aquí podemos disparar eventos globales para "sesión expirada" o notificaciones
  }
})
