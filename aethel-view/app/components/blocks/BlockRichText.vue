<script setup lang="ts">
interface Props {
  title?: string
  content: string
  editable?: boolean
}

const props = defineProps<Props>()
const toast = useToast()

const editableContent = ref(props.content)

function handleSave() {
  toast.add({
    title: 'Content saved',
    color: 'success',
    icon: 'i-lucide-check',
  })
}
</script>

<template>
  <div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
    <div
      v-if="title"
      class="px-4 py-3 border-b border-slate-100"
    >
      <h3 class="text-sm font-semibold text-slate-800">
        {{ title }}
      </h3>
    </div>

    <div class="p-4">
      <div v-if="editable" class="space-y-3">
        <textarea
          v-model="editableContent"
          class="w-full min-h-[160px] rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-700 font-mono focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent resize-y"
          placeholder="Enter HTML content..."
        />
        <UButton
          color="primary"
          variant="solid"
          size="sm"
          leading-icon="i-lucide-save"
          @click="handleSave"
        >
          Save
        </UButton>
      </div>

      <div
        v-else
        class="prose prose-sm prose-slate max-w-none text-slate-700 leading-relaxed"
        v-html="content"
      />
    </div>
  </div>
</template>
