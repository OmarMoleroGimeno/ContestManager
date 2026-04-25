import { ref, readonly } from 'vue'

const _meta = ref<{
  contest?: string
  category?: string
  round?: string
}>({})

export function useBreadcrumbMeta() {
  function setMeta(data: { contest?: string; category?: string; round?: string }) {
    if (data.contest !== undefined) _meta.value.contest = data.contest
    if (data.category !== undefined) _meta.value.category = data.category
    if (data.round !== undefined) _meta.value.round = data.round
  }

  function clearMeta() {
    _meta.value = {}
  }

  return { meta: readonly(_meta), setMeta, clearMeta }
}
