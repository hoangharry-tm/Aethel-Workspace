<script setup lang="ts">
interface Props {
  title: string
  value: string | number
  icon: string
  trend?: 'up' | 'down' | 'neutral'
  trendValue?: string
}

const props = defineProps<Props>()

const trendColor = computed(() => {
  if (props.trend === 'up') return 'text-emerald-600'
  if (props.trend === 'down') return 'text-rose-600'
  return 'text-icon-disabled'
})

const trendBg = computed(() => {
  if (props.trend === 'up') return 'bg-emerald-50'
  if (props.trend === 'down') return 'bg-rose-50'
  return 'bg-subtle'
})

const trendIcon = computed(() => {
  if (props.trend === 'up') return 'i-lucide-trending-up'
  if (props.trend === 'down') return 'i-lucide-trending-down'
  return 'i-lucide-minus'
})
</script>

<template>
  <div class="bg-surface rounded-xl border border-border-base p-5 flex items-start gap-4">
    <div class="flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-full bg-accent/10">
      <UIcon :name="icon" class="h-5 w-5 text-accent" />
    </div>
    <div class="flex-1 min-w-0">
      <p class="text-xs font-medium text-muted uppercase tracking-wider">
        {{ title }}
      </p>
      <p class="mt-1 text-2xl font-bold text-body tabular-nums">
        {{ value }}
      </p>
      <div
        v-if="trend && trendValue"
        class="mt-2 inline-flex items-center gap-1 rounded-full px-2 py-0.5"
        :class="trendBg"
      >
        <UIcon :name="trendIcon" class="h-3 w-3" :class="trendColor" />
        <span class="text-xs font-medium" :class="trendColor">{{ trendValue }}</span>
      </div>
    </div>
  </div>
</template>
