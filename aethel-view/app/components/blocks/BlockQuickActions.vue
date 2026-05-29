<script setup lang="ts">
interface ActionDef {
  label: string
  icon: string
  to?: string
  color?: string
}

interface Props {
  title?: string
  actions: ActionDef[]
}

defineProps<Props>()
</script>

<template>
  <div class="bg-surface rounded-xl border border-border-base overflow-hidden">
    <div
      v-if="title"
      class="px-4 py-3 border-b border-border-faint"
    >
      <h3 class="text-sm font-semibold text-body">
        {{ title }}
      </h3>
    </div>

    <div class="p-4">
      <div class="flex flex-wrap gap-2">
        <UButton
          v-for="action in actions"
          :key="action.label"
          :color="(action.color as 'primary' | 'neutral' | 'error' | 'warning' | 'success' | 'info') ?? 'neutral'"
          variant="outline"
          :leading-icon="action.icon"
          :to="action.to"
        >
          {{ action.label }}
        </UButton>
      </div>
    </div>
  </div>
</template>
