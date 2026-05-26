<script setup lang="ts">
import { useMockData } from '~/composables/useMockData'

definePageMeta({ layout: 'workspace' })

const { documents, currentUser } = useMockData()

const activeTab = ref<'action' | 'all'>('action')

const myDocs = computed(() =>
  documents.filter(d => d.recipientId === currentUser.value.id).slice(0, 4),
)

const actionDocs = computed(() =>
  myDocs.value.filter(d => d.status === 'IN_TRANSIT' || d.status === 'ATTEMPTED_DELIVERY'),
)

const visibleDocs = computed(() =>
  activeTab.value === 'action' ? actionDocs.value : myDocs.value,
)

function timeAgo(timestamp: string): string {
  const diff = Date.now() - new Date(timestamp).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  const days = Math.floor(hrs / 24)
  return `${days}d ago`
}

const tabs = [
  { key: 'action' as const, label: 'Awaiting My Action' },
  { key: 'all' as const, label: 'All' },
]
</script>

<template>
  <div class="space-y-6 max-w-5xl">
    <div>
      <h1 class="text-xl font-bold text-slate-800">
        My Documents
      </h1>
      <p class="text-sm text-slate-500 mt-0.5">
        Documents assigned to you
      </p>
    </div>

    <div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
      <!-- Filter tabs -->
      <div class="flex items-center border-b border-slate-200 px-4 pt-4">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
          :class="activeTab === tab.key
            ? 'border-indigo-600 text-indigo-600'
            : 'border-transparent text-slate-500 hover:text-slate-700'"
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
          <span
            v-if="tab.key === 'action' && actionDocs.length > 0"
            class="ml-1.5 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-rose-100 text-rose-600 text-[10px] font-semibold px-1"
          >
            {{ actionDocs.length }}
          </span>
        </button>
      </div>

      <!-- Empty state -->
      <div
        v-if="visibleDocs.length === 0"
        class="flex flex-col items-center justify-center py-16 text-center"
      >
        <UIcon name="i-lucide-check-circle" class="h-12 w-12 text-emerald-300 mb-3" />
        <p class="text-base font-semibold text-slate-600">
          You're all caught up!
        </p>
        <p class="text-sm text-slate-400 mt-1">
          No documents require your action right now.
        </p>
      </div>

      <!-- Table -->
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Tracking ID
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Subject
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider hidden sm:table-cell">
                Priority
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Status
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider hidden md:table-cell">
                Updated
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="doc in visibleDocs"
              :key="doc.id"
              class="hover:bg-slate-50 transition-colors"
            >
              <td class="px-4 py-3">
                <span class="font-mono text-xs text-slate-600">{{ doc.trackingNumber }}</span>
              </td>
              <td class="px-4 py-3 max-w-xs">
                <p class="text-sm font-medium text-slate-800 truncate">
                  {{ doc.subject }}
                </p>
              </td>
              <td class="px-4 py-3 hidden sm:table-cell">
                <UrgencyBadge :level="doc.urgency" />
              </td>
              <td class="px-4 py-3">
                <DocumentStatusBadge :status="doc.status" />
              </td>
              <td class="px-4 py-3 hidden md:table-cell">
                <span class="text-xs text-slate-500">{{ timeAgo(doc.updatedAt) }}</span>
              </td>
              <td class="px-4 py-3 text-right">
                <div class="flex justify-end gap-2">
                  <UButton
                    v-if="doc.status === 'IN_TRANSIT'"
                    :to="`/documents/${doc.id}`"
                    color="primary"
                    variant="soft"
                    size="xs"
                  >
                    Acknowledge
                  </UButton>
                  <UButton
                    :to="`/documents/${doc.id}`"
                    color="neutral"
                    variant="outline"
                    size="xs"
                  >
                    View
                  </UButton>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
