<script setup lang="ts">
definePageMeta({ layout: 'workspace' })
</script>

<template>
  <div class="space-y-6 max-w-3xl">
    <div>
      <h1 class="text-xl font-bold text-slate-800">
        Escalation Rules
      </h1>
      <p class="text-sm text-slate-500 mt-0.5">
        Configure automatic escalation thresholds and notification chains
      </p>
    </div>
    <UAlert
      color="warning"
      variant="soft"
      icon="i-lucide-construction"
      title="This section is under construction"
      description="Escalation rule management will be available in an upcoming release."
    />
  </div>
</template>
