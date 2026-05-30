<script setup>
import {
  reactive,
  ref,
  watch,
  computed,
  defineAsyncComponent,
  onMounted,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { convertToCategorySlug } from 'dashboard/helper/commons.js';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  mode: {
    type: String,
    required: true,
    validator: value => ['edit', 'create'].includes(value),
  },
  selectedCategory: {
    type: Object,
    default: () => ({}),
  },
  activeLocaleCode: {
    type: String,
    default: '',
  },
  showActionButtons: {
    type: Boolean,
    default: true,
  },
  portalName: {
    type: String,
    default: '',
  },
  activeLocaleName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['submit', 'cancel']);

const EmojiInput = defineAsyncComponent(
  () => import('shared/components/emoji/EmojiInput.vue')
);

const { t } = useI18n();
const route = useRoute();
const getters = useStoreGetters();

const isCreating = useMapGetter('categories/isCreating');

const isUpdatingCategory = computed(() => {
  const id = props.selectedCategory?.id;
  if (id) return getters['categories/uiFlags'].value(id)?.isUpdating;

  return false;
});

// Appy fork: the marketing site's CategoryIcon component recognises this
// allowlist of Lucide icon names and renders the matching <LucideIcon /> on
// the help portal landing. Names match lucide-react's PascalCase exports so
// the JSON value flows straight into the website without translation. To
// add a new icon: extend this list AND extend the website's
// app/components/help/CategoryIcon.tsx ICON_MAP to keep them in sync.
const LUCIDE_ICONS = Object.freeze([
  'Bell',
  'BookOpen',
  'Code',
  'Cog',
  'CreditCard',
  'HelpCircle',
  'Plug',
  'Rocket',
  'Settings',
  'Shield',
  'ShoppingBag',
  'Star',
  'Tag',
  'Users',
  'Zap',
]);
const LUCIDE_SET = new Set(LUCIDE_ICONS);
const pascalToKebab = name =>
  name.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();
const isLucideName = value =>
  typeof value === 'string' && LUCIDE_SET.has(value);

const state = reactive({
  id: '',
  name: '',
  icon: '',
  slug: '',
  description: '',
  locale: '',
});

const isIconPickerOpen = ref(false);
const iconPickerTab = ref('emoji');
const lucideSearch = ref('');

const filteredLucideIcons = computed(() => {
  const q = lucideSearch.value.trim().toLowerCase();
  if (!q) return LUCIDE_ICONS;
  return LUCIDE_ICONS.filter(name => name.toLowerCase().includes(q));
});

const iconButtonIcon = computed(() => {
  if (isLucideName(state.icon)) return `i-lucide-${pascalToKebab(state.icon)}`;
  if (state.icon) return '';
  return 'i-lucide-smile-plus';
});

const iconButtonLabel = computed(() =>
  state.icon && !isLucideName(state.icon) ? state.icon : ''
);

const isEditMode = computed(() => props.mode === 'edit');

const rules = {
  name: { required, minLength: minLength(1) },
  slug: { required },
};

const v$ = useVuelidate(rules, state);

const isSubmitDisabled = computed(() => v$.value.$invalid);

const nameError = computed(() =>
  v$.value.name.$error
    ? t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.NAME.ERROR')
    : ''
);

const slugError = computed(() =>
  v$.value.slug.$error
    ? t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.SLUG.ERROR')
    : ''
);

const slugHelpText = computed(() => {
  const { portalSlug, locale } = route.params;
  return t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.SLUG.HELP_TEXT', {
    portalSlug,
    localeCode: locale,
    categorySlug: state.slug,
  });
});

const onClickInsertEmoji = emoji => {
  state.icon = emoji;
  isIconPickerOpen.value = false;
};

const pickLucideIcon = name => {
  state.icon = name;
  isIconPickerOpen.value = false;
};

const clearIcon = () => {
  state.icon = '';
};

const handleSubmit = async () => {
  const isFormCorrect = await v$.value.$validate();
  if (!isFormCorrect) return;

  emit('submit', { ...state });
};

const handleCancel = () => {
  emit('cancel');
};

watch(
  () => state.name,
  () => {
    if (!isEditMode.value) {
      state.slug = convertToCategorySlug(state.name);
    }
  }
);

watch(
  () => props.selectedCategory,
  newCategory => {
    if (props.mode === 'edit' && newCategory) {
      const { id, name, icon, slug, description } = newCategory;
      Object.assign(state, { id, name, icon, slug, description });
    }
  },
  { immediate: true }
);

onMounted(() => {
  if (props.mode === 'create') {
    state.locale = props.activeLocaleCode;
  }
});

defineExpose({ state, isSubmitDisabled });
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      class="flex items-center justify-start gap-8 px-4 py-2 border rounded-lg border-n-strong"
    >
      <div class="flex flex-col items-start w-full gap-2 py-2">
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.HEADER.PORTAL') }}
        </span>
        <span class="text-sm text-n-slate-12">
          {{ portalName }}
        </span>
      </div>
      <div class="justify-start w-px h-10 bg-n-strong" />
      <div class="flex flex-col w-full gap-2 py-2">
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.HEADER.LOCALE') }}
        </span>
        <span
          :title="`${activeLocaleName} (${activeLocaleCode})`"
          class="text-sm line-clamp-1 text-n-slate-12"
        >
          {{ `${activeLocaleName} (${activeLocaleCode})` }}
        </span>
      </div>
    </div>
    <div class="flex flex-col gap-4">
      <div class="relative">
        <Input
          v-model="state.name"
          :label="
            t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.NAME.LABEL')
          "
          :placeholder="
            t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.NAME.PLACEHOLDER')
          "
          :message="nameError"
          :message-type="nameError ? 'error' : 'info'"
          custom-input-class="!h-10 ltr:!pl-12 rtl:!pr-12"
        >
          <template #prefix>
            <OnClickOutside @trigger="isIconPickerOpen = false">
              <Button
                :label="iconButtonLabel"
                color="slate"
                size="sm"
                type="button"
                :icon="iconButtonIcon"
                class="!h-[2.4rem] !w-[2.375rem] absolute top-[1.94rem] !outline-none !rounded-[0.438rem] border-0 ltr:left-px rtl:right-px ltr:!rounded-r-none rtl:!rounded-l-none"
                @click="isIconPickerOpen = !isIconPickerOpen"
              />
              <div
                v-if="isIconPickerOpen"
                class="absolute left-0 top-16 z-30 w-72 rounded-xl bg-n-alpha-3 outline outline-1 outline-n-container backdrop-blur-[100px] shadow-lg p-3 flex flex-col gap-3"
              >
                <div
                  class="flex items-center justify-between gap-2 border-b border-n-strong pb-2"
                >
                  <div class="flex items-center gap-1">
                    <button
                      type="button"
                      class="text-xs font-medium px-2 py-1 rounded transition-colors"
                      :class="
                        iconPickerTab === 'emoji'
                          ? 'bg-n-alpha-2 text-n-slate-12'
                          : 'text-n-slate-11 hover:text-n-slate-12'
                      "
                      @click="iconPickerTab = 'emoji'"
                    >
                      {{
                        t(
                          'HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.ICON_PICKER.EMOJI_TAB'
                        )
                      }}
                    </button>
                    <button
                      type="button"
                      class="text-xs font-medium px-2 py-1 rounded transition-colors"
                      :class="
                        iconPickerTab === 'lucide'
                          ? 'bg-n-alpha-2 text-n-slate-12'
                          : 'text-n-slate-11 hover:text-n-slate-12'
                      "
                      @click="iconPickerTab = 'lucide'"
                    >
                      {{
                        t(
                          'HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.ICON_PICKER.LIBRARY_TAB'
                        )
                      }}
                    </button>
                  </div>
                  <button
                    v-if="state.icon"
                    type="button"
                    :title="
                      t(
                        'HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.ICON_PICKER.CLEAR_TITLE'
                      )
                    "
                    class="text-xs text-n-slate-11 hover:text-n-slate-12 px-2 py-1 rounded hover:bg-n-alpha-2"
                    @click="clearIcon"
                  >
                    {{
                      t(
                        'HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.ICON_PICKER.CLEAR'
                      )
                    }}
                  </button>
                </div>
                <EmojiInput
                  v-if="iconPickerTab === 'emoji'"
                  class="!static !shadow-none !border-0 !bg-transparent !p-0"
                  show-remove-button
                  :on-click="onClickInsertEmoji"
                />
                <div v-else class="flex flex-col gap-2">
                  <input
                    v-model="lucideSearch"
                    type="search"
                    :placeholder="
                      t(
                        'HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.ICON_PICKER.SEARCH_PLACEHOLDER'
                      )
                    "
                    class="w-full h-8 rounded-md border border-n-strong bg-transparent px-2 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
                  />
                  <div
                    class="grid grid-cols-5 gap-1 max-h-[14rem] overflow-y-auto"
                  >
                    <button
                      v-for="name in filteredLucideIcons"
                      :key="name"
                      type="button"
                      :title="name"
                      class="flex items-center justify-center h-10 w-10 rounded hover:bg-n-alpha-2 transition-colors"
                      :class="
                        state.icon === name
                          ? 'bg-n-alpha-2 text-n-brand'
                          : 'text-n-slate-12'
                      "
                      @click="pickLucideIcon(name)"
                    >
                      <span
                        :class="`i-lucide-${pascalToKebab(name)} text-lg`"
                      />
                    </button>
                    <div
                      v-if="filteredLucideIcons.length === 0"
                      class="col-span-5 text-xs text-n-slate-11 text-center py-3"
                    >
                      {{
                        t(
                          'HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.ICON_PICKER.NO_RESULTS',
                          { query: lucideSearch }
                        )
                      }}
                    </div>
                  </div>
                </div>
              </div>
            </OnClickOutside>
          </template>
        </Input>
      </div>
      <Input
        v-model="state.slug"
        :label="t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.SLUG.LABEL')"
        :placeholder="
          t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.SLUG.PLACEHOLDER')
        "
        :disabled="isEditMode"
        :message="slugError ? slugError : slugHelpText"
        :message-type="slugError ? 'error' : 'info'"
        custom-input-class="!h-10"
      />
      <TextArea
        v-model="state.description"
        :label="
          t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.DESCRIPTION.LABEL')
        "
        :placeholder="
          t(
            'HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.FORM.DESCRIPTION.PLACEHOLDER'
          )
        "
        show-character-count
      />
      <div
        v-if="showActionButtons"
        class="flex items-center justify-between w-full gap-3"
      >
        <Button
          variant="faded"
          color="slate"
          :label="t('HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.BUTTONS.CANCEL')"
          class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
          @click="handleCancel"
        />
        <Button
          :label="
            t(
              `HELP_CENTER.CATEGORY_PAGE.CATEGORY_DIALOG.BUTTONS.${mode.toUpperCase()}`
            )
          "
          class="w-full"
          :disabled="isSubmitDisabled || isCreating || isUpdatingCategory"
          :is-loading="isCreating || isUpdatingCategory"
          @click="handleSubmit"
        />
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.emoji-dialog::before {
  @apply hidden;
}
</style>
