<script setup lang="ts">
import { useMockData } from "~/composables/useMockData";

definePageMeta({ layout: "workspace" });

const route = useRoute();
const { documents } = useMockData();

const searchQuery = ref((route.query.q as string) ?? "");
const statusFilter = ref("");
const urgencyFilter = ref("");
const docTypeFilter = ref("");

const statusOptions = [
  { label: "All Statuses", value: "" },
  { label: "Pending Assignment", value: "PENDING_ASSIGNMENT" },
  { label: "Under Review", value: "UNDER_REVIEW" },
  { label: "In Transit", value: "IN_TRANSIT" },
  { label: "Delivered", value: "DELIVERED" },
  { label: "Escalated", value: "ESCALATED" },
  { label: "Dispatched", value: "DISPATCHED" },
];

const urgencyOptions = [
  { label: "All Urgencies", value: "" },
  { label: "Immediate", value: "IMMEDIATE" },
  { label: "Priority", value: "PRIORITY" },
  { label: "Routine", value: "ROUTINE" },
];

const docTypeOptions = [
  { label: "All Types", value: "" },
  { label: "Audit Report", value: "Audit Report" },
  { label: "Legal Contract", value: "Legal Contract" },
  { label: "Invoice", value: "Invoice" },
  { label: "Regulatory Notice", value: "Regulatory Notice" },
  { label: "Budget Proposal", value: "Budget Proposal" },
  { label: "Report", value: "Report" },
];

const filteredResults = computed(() => {
  let results = [...documents];
  const q = searchQuery.value.toLowerCase().trim();

  if (q) {
    results = results.filter(
      (d) =>
        d.trackingNumber.toLowerCase().includes(q) ||
        d.senderName.toLowerCase().includes(q) ||
        d.senderOrg.toLowerCase().includes(q) ||
        d.subject.toLowerCase().includes(q),
    );
  }

  if (statusFilter.value) {
    results = results.filter((d) => d.status === statusFilter.value);
  }

  if (urgencyFilter.value) {
    results = results.filter((d) => d.urgency === urgencyFilter.value);
  }

  if (docTypeFilter.value) {
    results = results.filter((d) => d.documentType === docTypeFilter.value);
  }

  return results;
});

function timeAgo(timestamp: string): string {
  const diff = Date.now() - new Date(timestamp).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

const hasFilters = computed(
  () =>
    searchQuery.value ||
    statusFilter.value ||
    urgencyFilter.value ||
    docTypeFilter.value,
);

function clearFilters() {
  searchQuery.value = "";
  statusFilter.value = "";
  urgencyFilter.value = "";
  docTypeFilter.value = "";
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-xl font-bold text-slate-800">Search Documents</h1>
      <p class="text-sm text-slate-500 mt-0.5">
        Search by tracking number, sender, or subject
      </p>
    </div>

    <!-- Search bar -->
    <div class="relative">
      <UInput
        v-model="searchQuery"
        icon="i-lucide-search"
        placeholder="Search by tracking number, sender name, or subject..."
        size="lg"
        class="w-full"
      />
    </div>

    <!-- Filter chips -->
    <div class="flex flex-wrap gap-3 items-center">
      <USelect
        v-model="statusFilter"
        :items="statusOptions"
        size="sm"
        class="w-44"
      />
      <USelect
        v-model="urgencyFilter"
        :items="urgencyOptions"
        size="sm"
        class="w-36"
      />
      <USelect
        v-model="docTypeFilter"
        :items="docTypeOptions"
        size="sm"
        class="w-44"
      />
      <UButton
        v-if="hasFilters"
        color="neutral"
        variant="ghost"
        size="sm"
        leading-icon="i-lucide-x"
        @click="clearFilters"
      >
        Clear filters
      </UButton>
    </div>

    <!-- Results count -->
    <p v-if="hasFilters" class="text-sm text-slate-500">
      {{ filteredResults.length }} result{{
        filteredResults.length !== 1 ? "s" : ""
      }}
      found
    </p>

    <!-- Results table -->
    <div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th
                class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider"
              >
                Tracking ID
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider"
              >
                Subject
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider hidden sm:table-cell"
              >
                Sender
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider"
              >
                Priority
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider"
              >
                Status
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider hidden md:table-cell"
              >
                Time
              </th>
              <th
                class="px-4 py-3 text-right text-xs font-semibold text-slate-500 uppercase tracking-wider"
              >
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="doc in filteredResults"
              :key="doc.id"
              class="hover:bg-slate-50 transition-colors"
            >
              <td class="px-4 py-3">
                <span class="font-mono text-xs text-slate-600">{{
                  doc.trackingNumber
                }}</span>
              </td>
              <td class="px-4 py-3 max-w-xs">
                <p class="text-sm font-medium text-slate-800 truncate">
                  {{ doc.subject }}
                </p>
              </td>
              <td class="px-4 py-3 hidden sm:table-cell">
                <span class="text-xs text-slate-600">{{ doc.senderOrg }}</span>
              </td>
              <td class="px-4 py-3">
                <UrgencyBadge :level="doc.urgency" />
              </td>
              <td class="px-4 py-3">
                <DocumentStatusBadge :status="doc.status" />
              </td>
              <td class="px-4 py-3 hidden md:table-cell">
                <span class="text-xs text-slate-500">{{
                  timeAgo(doc.dateReceived)
                }}</span>
              </td>
              <td class="px-4 py-3 text-right">
                <UButton
                  :to="`/documents/${doc.id}`"
                  color="neutral"
                  variant="outline"
                  size="xs"
                >
                  View
                </UButton>
              </td>
            </tr>

            <!-- Empty state -->
            <tr v-if="filteredResults.length === 0">
              <td colspan="7" class="px-4 py-14 text-center">
                <UIcon
                  name="i-lucide-search-x"
                  class="h-10 w-10 text-slate-200 mx-auto mb-3"
                />
                <p class="text-sm font-medium text-slate-500">
                  No results found
                </p>
                <p class="text-xs text-slate-400 mt-1">
                  Try adjusting your search terms or filters
                </p>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
