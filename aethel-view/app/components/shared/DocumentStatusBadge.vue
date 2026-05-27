<script setup lang="ts">
interface Props {
  status: string
}

const props = defineProps<Props>()

type BadgeColor = 'neutral' | 'primary' | 'secondary' | 'info' | 'warning' | 'success' | 'error'

const statusConfig: Record<string, { color: BadgeColor, icon: string, label: string }> = {
  PENDING_ASSIGNMENT: { color: 'neutral', icon: 'i-lucide-clock', label: 'Pending Assignment' },
  UNDER_REVIEW: { color: 'primary', icon: 'i-lucide-eye', label: 'Under Review' },
  IN_TRANSIT: { color: 'info', icon: 'i-lucide-truck', label: 'In Transit' },
  ATTEMPTED_DELIVERY: { color: 'warning', icon: 'i-lucide-alert-circle', label: 'Attempted Delivery' },
  DELIVERED: { color: 'success', icon: 'i-lucide-check-circle', label: 'Delivered' },
  ESCALATED: { color: 'error', icon: 'i-lucide-bell-ring', label: 'Escalated' },
  DISPATCHED: { color: 'secondary', icon: 'i-lucide-send', label: 'Dispatched' },
}

const config = computed<{ color: BadgeColor, icon: string, label: string }>(() => {
  return statusConfig[props.status] ?? { color: 'neutral', icon: 'i-lucide-file', label: props.status }
})
</script>

<template>
  <UBadge
    :color="config.color"
    variant="soft"
    :leading-icon="config.icon"
    size="sm"
  >
    {{ config.label }}
  </UBadge>
</template>
