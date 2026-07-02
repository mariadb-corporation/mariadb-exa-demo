<template>
  <div class="kpi-card">
    <div class="kpi-icon">{{ icon }}</div>
    <div class="kpi-content">
      <div class="kpi-header">
        <div class="kpi-title">{{ title }}</div>
        <div v-if="queryTime !== null && showQueryTime" class="kpi-query-time">{{ queryTime }}ms</div>
      </div>
      <div class="kpi-value">{{ value }}</div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'KPICard',
  props: {
    title: {
      type: String,
      required: true
    },
    value: {
      type: [String, Number],
      required: true
    },
    icon: {
      type: String,
      default: '📊'
    },
    queryTime: {
      type: Number,
      default: null
    },
    showQueryTime: {
      type: Boolean,
      default: true
    }
  }
};
</script>

<style scoped>
.kpi-card {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.kpi-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.kpi-icon {
  font-size: 2.5rem;
  line-height: 1;
}

.kpi-content {
  flex: 1;
}

.kpi-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.kpi-title {
  font-size: 0.875rem;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.kpi-query-time {
  font-size: 0.75rem;
  color: #999;
  font-weight: 500;
}

.kpi-value {
  font-size: 1.75rem;
  font-weight: 600;
  color: #333;
}
</style>

