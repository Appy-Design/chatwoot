<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';

import ArticlesAPI from 'dashboard/api/helpCenter/articles';
import Button from 'dashboard/components-next/button/Button.vue';

// Appy fork: lets ops link an article to its translations in other locales
// of the same portal without dropping to the Rails console. Reads/writes
// article.associated_article_id; rendering of the cross-locale switcher on
// the marketing site already relies on associated_articles being populated,
// so this just closes the admin UI gap.

const props = defineProps({
  article: { type: Object, required: true },
});
const emit = defineEmits(['link', 'unlink', 'close']);

const { t } = useI18n();
const route = useRoute();

const portalBySlug = useMapGetter('portals/portalBySlug');
const portal = computed(() => portalBySlug.value(route.params.portalSlug));

// Translations form a group rooted at one article. Viewing the root gives
// us `associated_articles`; viewing a sibling gives us `root_article` plus
// its other siblings (which we can't reach from this article alone — we
// only know the root). So we render whatever siblings we can see and let
// ops navigate to the root if they need the full group.
const linkedTranslations = computed(() => {
  const own = props.article.id;
  const list = [
    props.article.root_article,
    ...(props.article.associated_articles || []),
  ].filter(a => a && a.id !== own);
  // De-dup by id (root_article may also appear inside associated_articles
  // depending on serializer order).
  const seen = new Set();
  return list.filter(a => {
    if (seen.has(a.id)) return false;
    seen.add(a.id);
    return true;
  });
});

const isTranslationOfRoot = computed(
  () => !!props.article.associated_article_id
);

// "Other locales" = portal locales minus the current article's own locale.
const otherLocales = computed(() => {
  const codes = portal.value?.config?.allowed_locales || [];
  const self = props.article.category?.locale || props.article.locale;
  return codes.filter(l => l.code !== self);
});

const selectedLocale = ref('');
const articlesForLocale = ref([]);
const isFetching = ref(false);
const searchQuery = ref('');

const fetchArticlesForLocale = async () => {
  if (!selectedLocale.value || !portal.value) {
    articlesForLocale.value = [];
    return;
  }
  isFetching.value = true;
  try {
    const response = await ArticlesAPI.getArticles({
      portalSlug: portal.value.slug,
      locale: selectedLocale.value,
    });
    articlesForLocale.value = response.data?.payload || [];
  } catch {
    articlesForLocale.value = [];
  } finally {
    isFetching.value = false;
  }
};

watch(selectedLocale, () => {
  searchQuery.value = '';
  fetchArticlesForLocale();
});

const filteredArticles = computed(() => {
  const linkedIds = new Set(linkedTranslations.value.map(a => a.id));
  // Exclude self + already-linked articles.
  const excluded = new Set([props.article.id, ...linkedIds]);
  const q = searchQuery.value.trim().toLowerCase();
  return articlesForLocale.value
    .filter(a => !excluded.has(a.id))
    .filter(a => {
      if (!q) return true;
      return (
        (a.title || '').toLowerCase().includes(q) ||
        (a.slug || '').toLowerCase().includes(q)
      );
    });
});

const localeLabel = code => {
  const match = (portal.value?.config?.allowed_locales || []).find(
    l => l.code === code
  );
  return match?.name || code;
};

const truncate = (s, n) => {
  if (!s) return '';
  return s.length > n ? `${s.slice(0, n)}…` : s;
};
</script>

<template>
  <div
    class="absolute flex flex-col w-[28rem] gap-4 p-4 rounded-xl shadow-lg z-30 bg-n-alpha-3 outline outline-1 outline-n-container backdrop-blur-[100px]"
  >
    <div class="flex items-center justify-between">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.TITLE') }}
      </h3>
      <Button
        icon="i-lucide-x"
        size="sm"
        variant="ghost"
        color="slate"
        @click="emit('close')"
      />
    </div>

    <div class="flex flex-col gap-1">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.LINKED_HEADING') }}
      </span>
      <ul v-if="linkedTranslations.length > 0" class="flex flex-col gap-1">
        <li
          v-for="a in linkedTranslations"
          :key="a.id"
          class="flex items-center justify-between gap-2 px-2 py-1.5 rounded bg-n-alpha-2"
        >
          <div class="flex-1 min-w-0">
            <div class="text-sm truncate text-n-slate-12">
              {{ a.title || a.slug }}
            </div>
            <div class="text-xs text-n-slate-10">
              {{ localeLabel(a.locale) }}{{ a.slug ? ` · ${a.slug}` : '' }}
            </div>
          </div>
        </li>
      </ul>
      <div v-else class="text-xs italic text-n-slate-10">
        {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.NO_LINKED') }}
      </div>
      <button
        v-if="isTranslationOfRoot"
        type="button"
        class="self-start mt-1 text-xs underline text-n-slate-11 hover:text-n-slate-12"
        @click="emit('unlink')"
      >
        {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.LEAVE_GROUP') }}
      </button>
    </div>

    <div class="flex flex-col gap-2 pt-3 border-t border-n-strong">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.ADD_HEADING') }}
      </span>
      <select
        v-model="selectedLocale"
        class="w-full h-8 px-2 text-sm bg-transparent border rounded-md border-n-strong text-n-slate-12 focus:outline-none focus:border-n-brand"
      >
        <option value="" disabled>
          {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.PICK_LOCALE') }}
        </option>
        <option v-for="loc in otherLocales" :key="loc.code" :value="loc.code">
          {{ loc.name || loc.code }}
        </option>
      </select>
      <input
        v-if="selectedLocale"
        v-model="searchQuery"
        type="search"
        :placeholder="
          t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.SEARCH_PLACEHOLDER')
        "
        class="w-full h-8 px-2 text-sm bg-transparent border rounded-md border-n-strong text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
      />
      <div
        v-if="selectedLocale"
        class="overflow-y-auto border rounded max-h-[14rem] border-n-strong"
      >
        <div v-if="isFetching" class="p-3 text-xs text-center text-n-slate-10">
          {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.LOADING') }}
        </div>
        <div
          v-else-if="filteredArticles.length === 0"
          class="p-3 text-xs text-center text-n-slate-10"
        >
          {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.TRANSLATIONS.NO_RESULTS') }}
        </div>
        <button
          v-for="a in filteredArticles"
          :key="a.id"
          type="button"
          class="flex flex-col items-start w-full gap-0.5 px-2 py-1.5 text-left hover:bg-n-alpha-2"
          @click="emit('link', a.id)"
        >
          <span class="w-full text-sm truncate text-n-slate-12">
            {{ a.title || a.slug }}
          </span>
          <span class="w-full text-xs truncate text-n-slate-10">
            {{ a.slug
            }}{{ a.description ? ` · ${truncate(a.description, 60)}` : '' }}
          </span>
        </button>
      </div>
    </div>
  </div>
</template>
