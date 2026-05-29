<script setup lang="ts">
export type TimelineEventType =
  | 'LOGGED'
  | 'ROUTED'
  | 'ROUTING_OVERRIDDEN'
  | 'NOTIFIED'
  | 'HANDOFF_ATTEMPTED'
  | 'DELIVERED'
  | 'ACKNOWLEDGED'
  | 'ESCALATED'

export interface TimelineEvent {
  id: string
  type: TimelineEventType
  actorName: string
  actorRole: string
  note?: string
  timestamp: string
}

interface Props {
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

const eventConfig: Record<TimelineEventType, { icon: string, color: string, label: string }> = {
  LOGGED: { icon: 'i-lucide-file-plus', color: 'bg-accent', label: 'Document Logged' },
  ROUTED: { icon: 'i-lucide-git-merge', color: 'bg-accent', label: 'Auto-Routed' },
  ROUTING_OVERRIDDEN: { icon: 'i-lucide-git-pull-request', color: 'bg-amber-500', label: 'Routing Overridden' },
  NOTIFIED: { icon: 'i-lucide-bell', color: 'bg-sky-500', label: 'Recipient Notified' },
  HANDOFF_ATTEMPTED: { icon: 'i-lucide-user-check', color: 'bg-amber-500', label: 'Handoff Attempted' },
  DELIVERED: { icon: 'i-lucide-check-circle', color: 'bg-emerald-500', label: 'Delivered' },
  ACKNOWLEDGED: { icon: 'i-lucide-badge-check', color: 'bg-emerald-500', label: 'Acknowledged by Recipient' },
  ESCALATED: { icon: 'i-lucide-bell-ring', color: 'bg-rose-500', label: 'Escalated' },
}
</script>

<template>
  <div class="flow-root">
    <ul class="-mb-8">
      <li
        v-for="(event, index) in events"
        :key="event.id"
        class="relative pb-8"
      >
        <!-- Connecting line -->
        <span
          v-if="index < events.length - 1"
          class="absolute left-4 top-4 -ml-px h-full w-0.5 bg-divider"
          aria-hidden="true"
        />

        <div class="relative flex items-start space-x-3">
          <!-- Icon dot -->
          <div class="relative flex items-center justify-center">
            <div
              class="flex h-8 w-8 items-center justify-center rounded-full ring-2 ring-white"
              :class="eventConfig[event.type]?.color ?? 'bg-icon-disabled'"
            >
              <UIcon
                :name="eventConfig[event.type]?.icon ?? 'i-lucide-circle'"
                class="h-4 w-4 text-white"
              />
            </div>
          </div>

          <!-- Content -->
          <div class="min-w-0 flex-1 pt-0.5">
            <div class="flex items-center justify-between gap-2 flex-wrap">
              <p class="text-sm font-medium text-body">
                {{ eventConfig[event.type]?.label ?? event.type }}
              </p>
              <time class="text-xs text-muted whitespace-nowrap">
                {{ timeAgo(event.timestamp) }}
              </time>
            </div>
            <div class="mt-0.5 flex items-center gap-1.5">
              <span class="text-xs text-muted">{{ event.actorName }}</span>
              <UBadge
                color="neutral"
                variant="soft"
                size="xs"
              >
                {{ event.actorRole }}
              </UBadge>
            </div>
            <p
              v-if="event.note"
              class="mt-1 text-xs text-muted italic"
            >
              "{{ event.note }}"
            </p>
          </div>
        </div>
      </li>
    </ul>
  </div>
</template>
