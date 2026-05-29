<script setup lang="ts">
import { useMockData } from '~/composables/useMockData'
import type { TimelineEvent } from '~/components/shared/EventTimeline.vue'

definePageMeta({ layout: 'workspace' })

const route = useRoute()
const { documents, currentUser } = useMockData()
const toast = useToast()

const doc = computed(() => {
  return documents.find(d => d.id === route.params.id) ?? documents[0]!
})

// Handoff modal
const showHandoffModal = ref(false)
const handoffPin = ref('')
const handoffLoading = ref(false)

async function confirmHandoff() {
  handoffLoading.value = true
  await new Promise(resolve => setTimeout(resolve, 800))
  handoffLoading.value = false
  showHandoffModal.value = false
  handoffPin.value = ''
  toast.add({
    title: 'Handoff confirmed',
    description: `Document ${doc.value?.trackingNumber} has been handed over.`,
    color: 'success',
    icon: 'i-lucide-check-circle',
  })
}

// Acknowledge modal
const showAckModal = ref(false)
const ackLoading = ref(false)

async function confirmAcknowledge() {
  ackLoading.value = true
  await new Promise(resolve => setTimeout(resolve, 600))
  ackLoading.value = false
  showAckModal.value = false
  toast.add({
    title: 'Receipt acknowledged',
    description: 'You have acknowledged receipt of this document.',
    color: 'success',
    icon: 'i-lucide-check-circle',
  })
}

function copyTracking() {
  if (doc.value) {
    navigator.clipboard.writeText(doc.value.trackingNumber)
    toast.add({
      title: 'Copied',
      description: `Tracking number ${doc.value.trackingNumber} copied to clipboard.`,
      color: 'neutral',
      icon: 'i-lucide-copy',
    })
  }
}

const timelineEvents = computed<TimelineEvent[]>(() => [
  {
    id: 'e1',
    type: 'LOGGED',
    actorName: 'Marcus Webb',
    actorRole: 'Reception',
    note: 'Document received via courier, sealed and intact.',
    timestamp: doc.value?.dateReceived ?? new Date().toISOString(),
  },
  {
    id: 'e2',
    type: 'ROUTED',
    actorName: 'System',
    actorRole: 'Routing Engine',
    note: `Auto-routed to ${doc.value?.department} department.`,
    timestamp: new Date(new Date(doc.value?.dateReceived ?? '').getTime() + 1000 * 60 * 5).toISOString(),
  },
  {
    id: 'e3',
    type: 'NOTIFIED',
    actorName: 'System',
    actorRole: 'Notification Service',
    note: 'Recipient notified via email and in-app alert.',
    timestamp: new Date(new Date(doc.value?.dateReceived ?? '').getTime() + 1000 * 60 * 8).toISOString(),
  },
  ...(doc.value?.status === 'ATTEMPTED_DELIVERY' || doc.value?.status === 'DELIVERED' || doc.value?.status === 'ESCALATED' ? [
    {
      id: 'e4',
      type: 'HANDOFF_ATTEMPTED' as const,
      actorName: 'James Okonkwo',
      actorRole: 'Reception',
      note: 'Recipient not available at desk. Left notification slip.',
      timestamp: new Date(new Date(doc.value?.dateReceived ?? '').getTime() + 1000 * 60 * 60).toISOString(),
    },
  ] : []),
  ...(doc.value?.status === 'DELIVERED' ? [
    {
      id: 'e5',
      type: 'DELIVERED' as const,
      actorName: 'Marcus Webb',
      actorRole: 'Reception',
      note: 'Document physically handed to recipient. PIN confirmed.',
      timestamp: doc.value?.updatedAt ?? new Date().toISOString(),
    },
  ] : []),
  ...(doc.value?.status === 'ESCALATED' ? [
    {
      id: 'e5',
      type: 'ESCALATED' as const,
      actorName: 'Alice Thornton',
      actorRole: 'Admin',
      note: 'Escalated due to delivery failure and urgency classification.',
      timestamp: doc.value?.updatedAt ?? new Date().toISOString(),
    },
  ] : []),
])

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

const deliveryModeLabel: Record<string, string> = {
  POST: 'Post',
  COURIER: 'Courier',
  HAND_DELIVERY: 'Hand Delivery',
  EMAIL: 'Email',
}
</script>

<template>
  <div class="space-y-6 max-w-6xl">
    <!-- Back -->
    <div class="flex items-center gap-3">
      <UButton
        icon="i-lucide-arrow-left"
        color="neutral"
        variant="ghost"
        size="sm"
        @click="$router.back()"
      />
      <h1 class="text-xl font-bold text-body">
        Document Detail
      </h1>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-5 gap-6">
      <!-- Left panel: 3/5 -->
      <div class="lg:col-span-3 space-y-4">
        <div class="bg-surface rounded-xl border border-border-base p-6 space-y-6">
          <!-- Tracking + badges -->
          <div>
            <div class="flex items-center gap-2 mb-2">
              <span class="font-mono text-lg font-bold text-body">{{ doc?.trackingNumber }}</span>
              <UButton
                icon="i-lucide-copy"
                color="neutral"
                variant="ghost"
                size="xs"
                @click="copyTracking"
              />
            </div>
            <div class="flex flex-wrap gap-2">
              <UrgencyBadge v-if="doc" :level="doc.urgency" />
              <DocumentStatusBadge v-if="doc" :status="doc.status" />
            </div>
          </div>

          <USeparator />

          <!-- Subject -->
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-icon-disabled mb-1">
              Subject
            </p>
            <p class="text-sm font-medium text-body">
              {{ doc?.subject }}
            </p>
          </div>

          <!-- Sender info -->
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-icon-disabled mb-3">
              Sender Information
            </p>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <p class="text-xs text-muted">
                  Name
                </p>
                <p class="text-sm font-medium text-body">
                  {{ doc?.senderName }}
                </p>
              </div>
              <div>
                <p class="text-xs text-muted">
                  Organization
                </p>
                <p class="text-sm font-medium text-body">
                  {{ doc?.senderOrg }}
                </p>
              </div>
              <div>
                <p class="text-xs text-muted">
                  Delivery Mode
                </p>
                <p class="text-sm font-medium text-body">
                  {{ deliveryModeLabel[doc?.deliveryMode ?? ''] ?? doc?.deliveryMode }}
                </p>
              </div>
              <div>
                <p class="text-xs text-muted">
                  Date Received
                </p>
                <p class="text-sm font-medium text-body">
                  {{ doc ? timeAgo(doc.dateReceived) : '' }}
                </p>
              </div>
            </div>
          </div>

          <!-- Routing -->
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-icon-disabled mb-3">
              Routing
            </p>
            <div class="mb-2">
              <p class="text-xs text-muted">
                Assigned To
              </p>
              <p class="text-sm font-medium text-body">
                {{ doc?.department }} Department
              </p>
            </div>
            <div v-if="doc && doc.routingChain.length > 1" class="flex items-center gap-1.5 flex-wrap">
              <template
                v-for="(stop, i) in doc.routingChain"
                :key="stop"
              >
                <UBadge color="neutral" variant="soft" size="xs">
                  {{ stop }}
                </UBadge>
                <UIcon
                  v-if="i < doc.routingChain.length - 1"
                  name="i-lucide-arrow-right"
                  class="h-3 w-3 text-icon-disabled"
                />
              </template>
            </div>
          </div>

          <!-- Attachments -->
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-icon-disabled mb-3">
              Attachments
            </p>
            <div
              v-for="file in doc?.attachments"
              :key="file"
              class="flex items-center gap-2 rounded-lg border border-border-base bg-subtle px-3 py-2"
            >
              <UIcon name="i-lucide-file-text" class="h-5 w-5 text-rose-500 flex-shrink-0" />
              <span class="text-sm text-body flex-1 truncate">{{ file }}</span>
              <UButton icon="i-lucide-download" color="neutral" variant="ghost" size="xs" />
            </div>
          </div>

          <!-- Action buttons -->
          <div class="flex flex-wrap gap-2 pt-2">
            <UButton
              v-if="currentUser.role === 'RECEPTION'"
              color="primary"
              variant="solid"
              leading-icon="i-lucide-hand"
              @click="showHandoffModal = true"
            >
              Mark as Handed Over
            </UButton>
            <UButton
              v-if="currentUser.role === 'USER'"
              color="primary"
              variant="solid"
              leading-icon="i-lucide-check-circle"
              @click="showAckModal = true"
            >
              Acknowledge Receipt
            </UButton>
            <UButton
              color="neutral"
              variant="outline"
              leading-icon="i-lucide-printer"
            >
              Print Tracking Slip
            </UButton>
          </div>
        </div>
      </div>

      <!-- Right panel: 2/5 -->
      <div class="lg:col-span-2">
        <div class="bg-surface rounded-xl border border-border-base p-6 sticky top-6">
          <h2 class="text-sm font-semibold text-body mb-6">
            Event Timeline
          </h2>
          <EventTimeline :events="timelineEvents" />
        </div>
      </div>
    </div>
  </div>

  <!-- Handoff confirmation modal -->
  <UModal v-model:open="showHandoffModal">
    <template #content>
      <div class="p-6 space-y-4">
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 items-center justify-center rounded-full bg-accent/10">
            <UIcon name="i-lucide-hand" class="h-5 w-5 text-accent" />
          </div>
          <div>
            <h3 class="text-base font-semibold text-body">
              Confirm Document Handoff
            </h3>
            <p class="text-xs text-muted">
              {{ doc?.trackingNumber }}
            </p>
          </div>
        </div>

        <p class="text-sm text-muted">
          I confirm this document has been physically handed to the recipient and they have acknowledged receipt.
        </p>

        <UFormField label="Confirmation PIN" name="pin">
          <UInput
            v-model="handoffPin"
            type="password"
            placeholder="Enter your PIN"
            icon="i-lucide-lock"
            class="w-full"
          />
        </UFormField>

        <div class="flex gap-2 pt-2">
          <UButton
            color="primary"
            variant="solid"
            :loading="handoffLoading"
            :disabled="!handoffPin"
            leading-icon="i-lucide-check"
            @click="confirmHandoff"
          >
            Confirm & Sign
          </UButton>
          <UButton
            color="neutral"
            variant="outline"
            @click="showHandoffModal = false"
          >
            Cancel
          </UButton>
        </div>
      </div>
    </template>
  </UModal>

  <!-- Acknowledge modal -->
  <UModal v-model:open="showAckModal">
    <template #content>
      <div class="p-6 space-y-4">
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 items-center justify-center rounded-full bg-emerald-100">
            <UIcon name="i-lucide-check-circle" class="h-5 w-5 text-emerald-600" />
          </div>
          <div>
            <h3 class="text-base font-semibold text-body">
              Acknowledge Receipt
            </h3>
            <p class="text-xs text-muted">
              {{ doc?.trackingNumber }}
            </p>
          </div>
        </div>

        <p class="text-sm text-muted">
          By clicking confirm, you acknowledge that you have received this document and accept responsibility for its handling.
        </p>

        <div class="flex gap-2 pt-2">
          <UButton
            color="primary"
            variant="solid"
            :loading="ackLoading"
            leading-icon="i-lucide-check"
            @click="confirmAcknowledge"
          >
            Confirm Receipt
          </UButton>
          <UButton
            color="neutral"
            variant="outline"
            @click="showAckModal = false"
          >
            Cancel
          </UButton>
        </div>
      </div>
    </template>
  </UModal>
</template>
