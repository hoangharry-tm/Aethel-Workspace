<script setup lang="ts">
import WorkspaceSidebar from '~/components/layout/WorkspaceSidebar.vue'
import WorkspaceNavbar from '~/components/layout/WorkspaceNavbar.vue'
import NotificationDrawer from '~/components/layout/NotificationDrawer.vue'
</script>

<template>
  <div class="h-dvh flex overflow-hidden bg-slate-50">
    <!-- Sidebar -->
    <WorkspaceSidebar />

    <!-- Main area -->
    <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
      <!-- Navbar -->
      <WorkspaceNavbar />

      <!-- Scrollable content -->
      <main class="flex-1 overflow-y-auto p-4 sm:p-6">
        <slot />
      </main>
    </div>

    <!-- Notification drawer (portal) -->
    <NotificationDrawer />
  </div>
</template>
