import { ApiService } from '../apiService'
import type { JudgePoolMember } from '~~/types'

/**
 * Módulo de la API dedicado a la gestión de Organizaciones.
 */
export class OrganizationsApi extends ApiService {
  async fetchJudgePool(orgId: string): Promise<JudgePoolMember[]> {
    return this.get<JudgePoolMember[]>(`/api/organizations/${orgId}/judge-pool`)
  }

  async saveToJudgePool(orgId: string, judge: Partial<JudgePoolMember>): Promise<JudgePoolMember> {
    return this.post<JudgePoolMember>(`/api/organizations/${orgId}/judge-pool`, judge)
  }

  async deleteFromJudgePool(orgId: string, judgeId: string): Promise<void> {
    return this.delete<void>(`/api/organizations/${orgId}/judge-pool/${judgeId}`)
  }
}

export const organizationsApi = new OrganizationsApi()
