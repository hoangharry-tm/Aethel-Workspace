<script setup lang="ts">
interface Column {
  key: string
  label: string
}

interface Props {
  title: string
  columns: Column[]
  rows: Record<string, unknown>[]
  emptyLabel?: string
}

const props = defineProps<Props>()

const sortKey = ref<string | null>(null)
const sortDir = ref<'asc' | 'desc'>('asc')

function toggleSort(key: string) {
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  }
  else {
    sortKey.value = key
    sortDir.value = 'asc'
  }
}

const sortedRows = computed(() => {
  if (!sortKey.value) return props.rows
  const key = sortKey.value
  return [...props.rows].sort((a, b) => {
    const av = a[key]
    const bv = b[key]
    const aStr = String(av ?? '')
    const bStr = String(bv ?? '')
    return sortDir.value === 'asc'
      ? aStr.localeCompare(bStr)
      : bStr.localeCompare(aStr)
  })
})
</script>

<template>
  <div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
    <div class="px-4 py-3 border-b border-slate-100">
      <h3 class="text-sm font-semibold text-slate-800">
        {{ title }}
      </h3>
    </div>

    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 border-b border-slate-200">
          <tr>
            <th
              v-for="col in columns"
              :key="col.key"
              class="px-4 py-2.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider cursor-pointer select-none hover:text-slate-700 transition-colors"
              @click="toggleSort(col.key)"
            >
              <div class="flex items-center gap-1">
                {{ col.label }}
                <UIcon
                  v-if="sortKey === col.key"
                  :name="sortDir === 'asc' ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
                  class="h-3 w-3"
                />
                <UIcon
                  v-else
                  name="i-lucide-chevrons-up-down"
                  class="h-3 w-3 text-slate-300"
                />
              </div>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <template v-if="sortedRows.length > 0">
            <tr
              v-for="(row, idx) in sortedRows"
              :key="idx"
              class="transition-colors"
              :class="idx % 2 === 1 ? 'bg-slate-50/50' : 'bg-white'"
            >
              <td
                v-for="col in columns"
                :key="col.key"
                class="px-4 py-2.5 text-slate-700"
              >
                {{ row[col.key] }}
              </td>
            </tr>
          </template>
          <tr v-else>
            <td :colspan="columns.length" class="px-4 py-10 text-center">
              <div class="flex flex-col items-center gap-2 text-slate-400">
                <UIcon name="i-lucide-inbox" class="h-8 w-8" />
                <span class="text-sm">{{ emptyLabel ?? 'No data available' }}</span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
