import { storeToRefs } from 'pinia'
import { useContestStore } from '../stores/contest'

export const useContest = () => {
  const store = useContestStore()
  const { currentContest, categories, rounds, participants } = storeToRefs(store)
  return {
    currentContest,
    categories,
    rounds,
    participants,
    fetchContest: store.fetchContest
  }
}
