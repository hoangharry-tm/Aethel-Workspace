<script setup lang="ts">
interface TimelineEvent {
  label: string
  note?: string
  timestamp: string
  icon: string
  color: string
}

interface Props {
  title: string
  events: TimelineEvent[]
}

defineProps<Props>()

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
</script>

<template>
  <div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
    <div class="px-4 py-3 border-b border-slate-100">
      <h3 class="text-sm font-semibold text-slate-800">
        {{ title }}
      </h3>
    </div>

    <div class="p-4">
      <div class="flow-root">
        <ul class="-mb-8">
          <li
            v-for="(event, index) in events"
            :key="index"
            class="relative pb-8"
          >
            <!-- Connecting line -->
            <span
              v-if="index < events.length - 1"
              class="absolute left-4 top-4 -ml-px h-full w-0.5 bg-slate-200"
              aria-hidden="true"
            />

            <div class="relative flex items-start space-x-3">
              <!-- Icon dot -->
              <div class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full ring-2 ring-white" :class="event.color">
                <UIcon :name="event.icon" class="h-4 w-4 text-white" />
              </div>

              <!-- Content -->
              <div class="min-w-0 flex-1 pt-0.5">
                <div class="flex items-center justify-between gap-2 flex-wrap">
                  <p class="text-sm font-medium text-slate-900">
                    {{ event.label }}
                  </p>
                  <time class="text-xs text-slate-500 whitespace-nowrap">
                    {{ timeAgo(event.timestamp) }}
                  </time>
                </div>
                <p
                  v-if="event.note"
                  class="mt-1 text-xs text-slate-500 italic"
                >
                  "{{ event.note }}"
                </p>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>
