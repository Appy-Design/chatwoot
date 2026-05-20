<script setup>
import { onMounted, computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useMapGetter } from 'dashboard/composables/store.js';
import { useRouter } from 'vue-router';

import Banner from 'dashboard/components-next/banner/Banner.vue';

const router = useRouter();
const { accountId } = useAccount();
const globalConfig = useMapGetter('globalConfig/get');

const { documentLimits, fetchLimits } = useCaptain();

const openBilling = () => {
  router.push({
    name: 'billing_settings_index',
    params: { accountId: accountId.value },
  });
};

const showBanner = computed(() => {
  if (globalConfig.value?.appyInstallation) return false;
  if (!documentLimits.value) return false;

  const { currentAvailable } = documentLimits.value;
  return currentAvailable === 0;
});

onMounted(fetchLimits);
</script>

<template>
  <Banner
    v-show="showBanner"
    color="amber"
    :action-label="$t('CAPTAIN.PAYWALL.UPGRADE_NOW')"
    @action="openBilling"
  >
    {{ $t('CAPTAIN.BANNER.DOCUMENTS') }}
  </Banner>
</template>
