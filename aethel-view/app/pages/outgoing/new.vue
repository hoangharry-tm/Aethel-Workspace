<script setup lang="ts">
definePageMeta({ layout: 'workspace' })

const router = useRouter()
const toast = useToast()

const form = reactive({
  recipientName: '',
  recipientOrgAddress: '',
  documentType: '',
  urgency: 'ROUTINE',
  notes: '',
})

const loading = ref(false)

const documentTypeOptions = [
  { label: 'Report', value: 'Report' },
  { label: 'Invoice', value: 'Invoice' },
  { label: 'Legal Contract', value: 'Legal Contract' },
  { label: 'MOU', value: 'MOU' },
  { label: 'General Correspondence', value: 'General Correspondence' },
  { label: 'Certificate', value: 'Certificate' },
  { label: 'Budget Proposal', value: 'Budget Proposal' },
]

const urgencyOptions = [
  { label: 'Routine', value: 'ROUTINE' },
  { label: 'Priority', value: 'PRIORITY' },
  { label: 'Immediate', value: 'IMMEDIATE' },
]

async function handleSubmit() {
  loading.value = true
  await new Promise(resolve => setTimeout(resolve, 800))
  loading.value = false
  toast.add({
    title: 'Outgoing request submitted',
    description: 'Reception has been notified and will process your request.',
    color: 'success',
    icon: 'i-lucide-check-circle',
  })
  await router.push('/my-documents')
}
</script>

<template>
  <div class="space-y-6 max-w-2xl">
    <div class="flex items-center gap-3">
      <UButton
        icon="i-lucide-arrow-left"
        color="neutral"
        variant="ghost"
        size="sm"
        @click="$router.back()"
      />
      <div>
        <h1 class="text-xl font-bold text-slate-800">
          Submit Outgoing Request
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">
          Request reception to dispatch a document on your behalf
        </p>
      </div>
    </div>

    <form @submit.prevent="handleSubmit">
      <div class="bg-white rounded-xl border border-slate-200 p-6 space-y-5">
        <UFormField label="Recipient Name" name="recipientName" required>
          <UInput
            v-model="form.recipientName"
            placeholder="Full name of recipient"
            class="w-full"
          />
        </UFormField>

        <UFormField label="Recipient Organization / Address" name="recipientOrgAddress" required>
          <UTextarea
            v-model="form.recipientOrgAddress"
            placeholder="Organization and delivery address"
            :rows="2"
            class="w-full"
          />
        </UFormField>

        <UFormField label="Document Type" name="documentType" required>
          <USelect
            v-model="form.documentType"
            :items="documentTypeOptions"
            placeholder="Select document type"
            class="w-full"
          />
        </UFormField>

        <UFormField label="Urgency" name="urgency">
          <USelect
            v-model="form.urgency"
            :items="urgencyOptions"
            class="w-full"
          />
        </UFormField>

        <!-- Attachment zone -->
        <div>
          <p class="text-sm font-medium text-slate-700 mb-2">
            Attachment (Optional)
          </p>
          <div class="border-2 border-dashed border-slate-200 rounded-lg p-6 flex flex-col items-center justify-center text-center hover:border-indigo-300 hover:bg-indigo-50/30 transition-colors cursor-pointer">
            <UIcon name="i-lucide-upload-cloud" class="h-8 w-8 text-slate-300 mb-2" />
            <p class="text-sm text-slate-500">
              Drag file here or click to browse
            </p>
            <p class="text-xs text-slate-400 mt-0.5">
              Maximum 25MB
            </p>
          </div>
        </div>

        <UFormField label="Notes / Instructions" name="notes">
          <UTextarea
            v-model="form.notes"
            placeholder="Any special handling instructions for reception..."
            :rows="3"
            class="w-full"
          />
        </UFormField>
      </div>

      <div class="flex items-center gap-3 mt-6">
        <UButton
          type="submit"
          color="primary"
          variant="solid"
          :loading="loading"
          leading-icon="i-lucide-send"
        >
          Submit Request
        </UButton>
        <UButton
          type="button"
          color="neutral"
          variant="outline"
          to="/my-documents"
        >
          Cancel
        </UButton>
      </div>
    </form>
  </div>
</template>
