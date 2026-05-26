<template>
  <div class="min-h-screen bg-slate-50 flex flex-col items-center justify-center px-4 py-12">
    <!-- Brand header -->
    <div class="flex items-center gap-2.5 mb-8">
      <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-600 shadow-sm">
        <UIcon name="i-lucide-building-2" class="h-6 w-6 text-white" />
      </div>
      <span class="text-xl font-bold text-slate-800">Aethel Workspace</span>
    </div>

    <!-- Card slot -->
    <div class="w-full max-w-md bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
      <slot />
    </div>

    <!-- Footer -->
    <p class="mt-6 text-xs text-slate-400">
      &copy; {{ new Date().getFullYear() }} Aethel Workspace. All rights reserved.
    </p>
  </div>
</template>
