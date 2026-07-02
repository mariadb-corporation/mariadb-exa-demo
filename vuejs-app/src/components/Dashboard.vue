<template>
  <div class="dashboard">
    <!-- KPI Cards -->
    <div class="kpi-grid">
      <KPICard 
        title="Total Sales" 
        :value="formatNumber(stats.totalSales)" 
        icon="📊"
        :query-time="stats.queryTime"
      />
      <KPICard 
        title="Items Sold" 
        :value="formatNumber(stats.itemsSold)" 
        icon="📦"
        :query-time="stats.itemsSoldQueryTime"
      />
      <KPICard 
        title="Orders/Min" 
        :value="formatNumber(kpis.ordersPerMinute, 2)" 
        icon="⚡"
        :query-time="kpis.ordersPerMinQueryTime"
      />
      <KPICard 
        title="Items/Min" 
        :value="formatNumber(kpis.itemsPerMinute, 2)" 
        icon="🚀"
        :query-time="kpis.itemsPerMinQueryTime"
      />
      <KPICard 
        title="API Latency" 
        :value="`${formatNumber(kpis.apiLatency, 2)}ms`" 
        icon="⏱️"
        :show-query-time="false"
      />
    </div>

    <!-- Charts Row 1 -->
    <div class="charts-row">
      <div class="chart-card">
        <div class="chart-header">
          <h2>Sales by Region</h2>
          <div class="header-right">
            <button 
              @click="refreshRegionData" 
              :disabled="isRefreshingRegion"
              class="refresh-button"
              title="Refresh region data"
            >
              <span class="refresh-icon" :class="{ spinning: isRefreshingRegion }">↻</span>
            </button>
            <span v-if="regionQueryTime" class="query-time">{{ regionQueryTime }}ms</span>
          </div>
        </div>
        <BarChart 
          v-if="regionData.length > 0"
          :data="regionData"
          :labels="regionData.map(r => r.region)"
          :values="regionData.map(r => r.total_revenue)"
          label="Revenue ($)"
        />
        <div v-else class="loading">Loading...</div>
      </div>

      <div class="chart-card">
        <div class="chart-header">
          <h2>Top Products</h2>
          <div class="header-right">
            <button 
              @click="refreshProductData" 
              :disabled="isRefreshingProduct"
              class="refresh-button"
              title="Refresh product data"
            >
              <span class="refresh-icon" :class="{ spinning: isRefreshingProduct }">↻</span>
            </button>
            <span v-if="productQueryTime" class="query-time">{{ productQueryTime }}ms</span>
          </div>
        </div>
        <BarChart 
          v-if="productData.length > 0"
          :data="productData.slice(0, 10)"
          :labels="productData.slice(0, 10).map(p => p.product)"
          :values="productData.slice(0, 10).map(p => p.total_revenue)"
          label="Revenue ($)"
        />
        <div v-else class="loading">Loading...</div>
      </div>
    </div>

    <!-- Sales per Day with Slider -->
    <div class="chart-card full-width">
      <div class="chart-header">
        <h2>Total Sales Revenue per Day</h2>
        <div class="header-right">
          <div class="range-control">
            <label for="dayRange">Days: {{ dayRange }}</label>
            <input 
              id="dayRange"
              type="range" 
              min="1" 
              max="90" 
              v-model.number="dayRange"
              @input="loadDailyData"
              class="range-slider"
            />
          </div>
          <span v-if="dailyQueryTime" class="query-time">{{ dailyQueryTime }}ms</span>
        </div>
      </div>
      <LineChart 
        v-if="dailyData.length > 0"
        :data="dailyData"
        :labels="dailyLabels"
        :values="dailyValues"
        label="Revenue ($)"
      />
      <div v-else class="loading">Loading...</div>
    </div>

    <!-- Realtime Chart -->
    <div class="chart-card full-width">
      <RealtimeChart 
        :secondly-data="realtimeData.secondly"
        :current-second="realtimeData.currentSecond"
        :queryTime="realtimeData.queryTime"
      />
    </div>
  </div>
</template>

<script>
import axios from 'axios';
import KPICard from './KPICard.vue';
import BarChart from './BarChart.vue';
import LineChart from './LineChart.vue';
import RealtimeChart from './RealtimeChart.vue';

// Measure request start time
axios.interceptors.request.use(config => {
  config.meta = { start: performance.now() };
  return config;
});

// Measure full round-trip time once response arrives
axios.interceptors.response.use(response => {
  response.duration = performance.now() - response.config.meta.start;
  // console.log(`${response.config.method} ${response.config.url}: ${response.duration}ms`);
  return response;
});

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

export default {
  name: 'Dashboard',
  components: {
    KPICard,
    BarChart,
    LineChart,
    RealtimeChart
  },
  props: {
    useExa: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
      stats: {
        totalSales: 0,
        itemsSold: 0,
        queryTime: null,
        itemsSoldQueryTime: null
      },
      kpis: {
        ordersPerMinute: 0,
        itemsPerMinute: 0,
        apiLatency: 0,
        ordersPerMinQueryTime: null,
        itemsPerMinQueryTime: null
      },
      regionData: [],
      productData: [],
      regionQueryTime: null,
      productQueryTime: null,
      isRefreshingRegion: false,
      isRefreshingProduct: false,
      dailyData: [],
      dailyLabels: [],
      dailyValues: [],
      dailyQueryTime: null,
      dayRange: 7,
      isLoadingDailyData: false,
      realtimeData: {
        secondly: [],
        currentSecond: { order_count: 0, revenue: 0 },
        queryTime: 0
      },
      eventSource: null,
      abortControllers: [],
      pollingInterval: null
    };
  },
  mounted() {
    this.loadInitialData();
    this.startRealtimeUpdates();
    this.startKPIPolling();
    
    // Listen for database changes
    window.addEventListener('database-changed', this.handleDatabaseChange);
  },
  beforeUnmount() {
    this.cancelAllRequests();
    if (this.eventSource) {
      this.eventSource.close();
    }
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
    window.removeEventListener('database-changed', this.handleDatabaseChange);
  },
  watch: {
    useExa(newVal) {
      // Cancel all outstanding requests
      this.cancelAllRequests();
      
      // Reset all data to zero/empty state to show new data needs to be loaded
      this.resetAllData();
      
      // Reload data when database changes
      this.loadInitialData();
      if (this.eventSource) {
        this.eventSource.close();
      }
      this.startRealtimeUpdates();
      this.startKPIPolling();
    }
  },
  methods: {
    cancelAllRequests() {
      // Cancel all pending axios requests
      this.abortControllers.forEach(controller => {
        controller.abort();
      });
      this.abortControllers = [];
      
      // Close EventSource connection
      if (this.eventSource) {
        this.eventSource.close();
        this.eventSource = null;
      }
      
      // Clear polling interval
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval);
        this.pollingInterval = null;
      }
    },
    resetAllData() {
      // Reset all stats to zero
      this.stats = {
        totalSales: 0,
        itemsSold: 0,
        queryTime: null,
        itemsSoldQueryTime: null
      };
      
      // Reset all KPIs to zero
      this.kpis = {
        ordersPerMinute: 0,
        itemsPerMinute: 0,
        apiLatency: 0,
        ordersPerMinQueryTime: null,
        itemsPerMinQueryTime: null
      };
      
      // Reset chart data
      this.regionData = [];
      this.productData = [];
      this.regionQueryTime = null;
      this.productQueryTime = null;
      
      // Reset daily chart data
      this.dailyData = [];
      this.dailyLabels = [];
      this.dailyValues = [];
      this.dailyQueryTime = null;
      
      // Reset realtime data
      this.realtimeData = {
        secondly: [],
        currentSecond: { order_count: 0, revenue: 0 },
        queryTime: 0
      };
    },
    handleDatabaseChange() {
      // Cancel all outstanding requests
      this.cancelAllRequests();
      
      // Reset all data to zero/empty state to show new data needs to be loaded
      this.resetAllData();
      
      // Reload all data when database changes
      this.loadInitialData();
      if (this.eventSource) {
        this.eventSource.close();
      }
      this.startRealtimeUpdates();
      this.startKPIPolling();
    },
    getApiUrl(path) {
      const separator = path.includes('?') ? '&' : '?';
      return `${API_URL}${path}${separator}exa=${this.useExa}`;
    },
    async loadInitialData() {
      // Create abort controller for this batch of requests
      const abortController = new AbortController();
      this.abortControllers.push(abortController);
      
      try {
        // Load all stats in parallel
        const [totalSales, itemsSold, byRegion, byProduct, daily7, apiLatency] = await Promise.all([
          axios.get(this.getApiUrl('/api/stats/total-sales'), { signal: abortController.signal }),
          axios.get(this.getApiUrl('/api/stats/items-sold'), { signal: abortController.signal }),
          axios.get(this.getApiUrl('/api/stats/by-region'), { signal: abortController.signal }),
          axios.get(this.getApiUrl('/api/stats/by-product'), { signal: abortController.signal }),
          axios.get(this.getApiUrl(`/api/stats/daily?range=7`), { signal: abortController.signal }),
          axios.get(this.getApiUrl('/api/kpi/api-latency'), { signal: abortController.signal })
        ]);

        this.kpis.apiLatency = apiLatency.duration || 0;
        this.stats.totalSales = totalSales.data.total;
        this.stats.queryTime = totalSales.data.queryTime;
        this.stats.itemsSold = itemsSold.data.total;
        this.stats.itemsSoldQueryTime = itemsSold.data.queryTime;
        this.regionData = byRegion.data.data || byRegion.data;
        this.regionQueryTime = byRegion.data.queryTime;
        this.productData = byProduct.data.data || byProduct.data;
        this.productQueryTime = byProduct.data.queryTime;
        
        // Process daily data to ensure correct structure
        const dailyDataRaw = daily7.data.data || daily7.data;
        if (Array.isArray(dailyDataRaw)) {
          this.dailyData = dailyDataRaw.map(item => {
            // Ensure revenue is properly parsed as a number
            const revenue = item.revenue !== null && item.revenue !== undefined 
              ? parseFloat(item.revenue) || 0 
              : 0;
            
            return {
              date: item.date || item.created_at || null,
              revenue: revenue,
              order_count: Number(item.order_count) || 0,
              items_sold: Number(item.items_sold) || 0
            };
          }).filter(item => item.date !== null);
          
          console.log('Initial daily data loaded:', this.dailyData.length, 'days');
          // console.log('Sample revenue values:', this.dailyData.slice(0, 5).map(d => ({ date: d.date, revenue: d.revenue })));
          
          // Pre-compute labels and values
          this.updateDailyChartData();
        } else {
          this.dailyData = [];
          this.dailyLabels = [];
          this.dailyValues = [];
        }
        this.dailyQueryTime = daily7.data.queryTime;
        
        // Remove this controller from the list since request completed
        const index = this.abortControllers.indexOf(abortController);
        if (index > -1) {
          this.abortControllers.splice(index, 1);
        }
      } catch (error) {
        if (error.name === 'CanceledError' || error.name === 'AbortError' || axios.isCancel(error)) {
          // Request was cancelled, ignore the error
          return;
        }
        console.error('Error loading initial data:', error);
        
        // Remove this controller from the list
        const index = this.abortControllers.indexOf(abortController);
        if (index > -1) {
          this.abortControllers.splice(index, 1);
        }
      }
    },
    async loadDailyData() {
      // Prevent multiple concurrent requests
      if (this.isLoadingDailyData) {
        return;
      }
      
      this.isLoadingDailyData = true;
      
      // Create abort controller for this request
      const abortController = new AbortController();
      this.abortControllers.push(abortController);
      
      try {
        const response = await axios.get(this.getApiUrl(`/api/stats/daily?range=${this.dayRange}`), { signal: abortController.signal });
        const data = response.data.data || response.data;
        
        // Debug logging
        // console.log('Daily data API response:', response.data);
        // console.log('Raw data array length:', Array.isArray(data) ? data.length : 'not an array');
        // console.log('Day range setting:', this.dayRange);
        
        // Ensure data is an array and has the correct structure
        if (Array.isArray(data)) {
          
          this.dailyData = data.map(item => {
            // Ensure date is a string, not an object
            let dateValue = item.date || item.created_at || null;
            if (dateValue && typeof dateValue !== 'string') {
              // If it's a Date object or other type, convert to string
              if (dateValue instanceof Date) {
                dateValue = dateValue.toISOString().split('T')[0]; // YYYY-MM-DD
              } else {
                dateValue = String(dateValue);
              }
            }
            
            // Ensure revenue is properly parsed as a number (total sales revenue per day)
            const revenue = item.revenue !== null && item.revenue !== undefined 
              ? parseFloat(item.revenue) || 0 
              : 0;
            
            return {
              date: dateValue,
              revenue: revenue,
              order_count: Number(item.order_count) || 0,
              items_sold: Number(item.items_sold) || 0
            };
          }).filter(item => item.date !== null && item.date !== '');
          
          // console.log('Filtered dailyData length:', this.dailyData.length);
          // console.log('Sample dates:', this.dailyData.slice(0, 5).map(d => d.date));
          
          // Pre-compute labels and values
          this.updateDailyChartData();
          
          // console.log('Final dailyData count:', this.dailyData.length);
          // console.log('Daily labels count:', this.dailyLabels.length);
          // console.log('Daily values count:', this.dailyValues.length);
          
          // Force Vue to recognize the change by using $nextTick
          // this.$nextTick(() => {
          //   console.log('Chart should update with new data');
          // });
        } else {
          console.warn('Daily data is not an array:', data);
          this.dailyData = [];
          this.dailyLabels = [];
          this.dailyValues = [];
        }
        this.dailyQueryTime = response.data.queryTime;
        
        // Remove this controller from the list since request completed
        const index = this.abortControllers.indexOf(abortController);
        if (index > -1) {
          this.abortControllers.splice(index, 1);
        }
      } catch (error) {
        if (error.name === 'CanceledError' || error.name === 'AbortError' || axios.isCancel(error)) {
          // Request was cancelled, ignore the error
          return;
        }
        console.error('Error loading daily data:', error);
        this.dailyData = [];
        this.dailyLabels = [];
        this.dailyValues = [];
      } finally {
        this.isLoadingDailyData = false;
        
        // Remove this controller from the list if still present
        const index = this.abortControllers.indexOf(abortController);
        if (index > -1) {
          this.abortControllers.splice(index, 1);
        }
      }
    },
    updateDailyChartData() {
      // Compute labels and values from dailyData
      this.dailyLabels = this.dailyData
        .filter(d => d && d.date)
        .map(d => {
          // Debug logging
          // console.log('Processing date:', d.date, 'Type:', typeof d.date, 'Is Date:', d.date instanceof Date);
          
          // Ensure we always return a string
          if (!d.date) {
            console.warn('Empty date found:', d);
            return '';
          }
          
          // If it's already a string, format it
          if (typeof d.date === 'string') {
            const formatted = this.formatDate(d.date);
            // console.log('Formatted date string:', d.date, '->', formatted);
            return formatted || d.date;
          }
          
          // If it's a Date object, format it
          if (d.date instanceof Date) {
            const formatted = d.date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
            console.log('Formatted Date object ->', formatted);
            return formatted;
          }
          
          // Fallback: convert to string
          console.warn('Date is not string or Date, converting:', d.date);
          return String(d.date);
        })
        .filter(label => label !== ''); // Remove empty labels
      
      this.dailyValues = this.dailyData
        .filter(d => d && d.date)
        .map(d => {
          // Ensure revenue is a number - this is the total sales revenue per day
          const revenue = d.revenue !== null && d.revenue !== undefined 
            ? parseFloat(d.revenue) || 0 
            : 0;
          return revenue;
        });
      
      // console.log('Final labels array:', this.dailyLabels);
      // console.log('Final values array:', this.dailyValues);
      // console.log('Sample revenue values:', this.dailyValues.slice(0, 5));
      // console.log('Sample dailyData with revenue:', this.dailyData.slice(0, 5).map(d => ({ date: d.date, revenue: d.revenue })));
    },
    startRealtimeUpdates() {
      // Use Server-Sent Events for realtime updates
      this.eventSource = new EventSource(this.getApiUrl('/api/realtime'));

      this.eventSource.onmessage = (event) => {

        try {
          const data = JSON.parse(event.data);
          
          if (data.type === 'update') {
            // Ensure secondly is an array
            const secondly = Array.isArray(data.secondly) ? data.secondly : [];
            //console.log('/api/realtime received:', { secondly: secondly, currentSecond: data.currentSecond, queryTime: data.queryTime });
            
            this.realtimeData = {
              secondly: secondly,
              currentSecond: data.currentSecond || { order_count: 0, revenue: 0 },
              queryTime: data.queryTime
            };
          }
        } catch (error) {
          console.error('Error parsing realtime data:', error);
        }
      };

      this.eventSource.onerror = (error) => {
        console.error('SSE error:', error);
        // Attempt to reconnect after 3 seconds
        setTimeout(() => {
          if (this.eventSource.readyState === EventSource.CLOSED) {
            this.startRealtimeUpdates();
          }
        }, 3000);
      };
    },
    async startKPIPolling() {
      // Clear any existing polling interval
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval);
      }
      
      const updateKPIs = async () => {
        // Create abort controller for this batch of requests
        const abortController = new AbortController();
        this.abortControllers.push(abortController);
        
        try {
          const [
            totalSales,
            itemsSold,
            ordersPerMin,
            itemsPerMin,
            apiLatency
          ] = await Promise.all([
            axios.get(this.getApiUrl('/api/stats/total-sales'), { signal: abortController.signal }),
            axios.get(this.getApiUrl('/api/stats/items-sold'), { signal: abortController.signal }),
            axios.get(this.getApiUrl('/api/kpi/orders-per-minute'), { signal: abortController.signal }),
            axios.get(this.getApiUrl('/api/kpi/items-per-minute'), { signal: abortController.signal }),
            axios.get(this.getApiUrl('/api/kpi/api-latency'), { signal: abortController.signal })
          ]);
    
          // 🔹 Refresh the top two cards
          this.stats.totalSales = totalSales.data.total || 0;
          this.stats.queryTime = totalSales.data.queryTime;
          this.stats.itemsSold = itemsSold.data.total || 0;
          this.stats.itemsSoldQueryTime = itemsSold.data.queryTime;
    
          // 🔹 Refresh the KPI cards
          this.kpis.ordersPerMinute = ordersPerMin.data.ordersPerMinute || 0;
          this.kpis.ordersPerMinQueryTime = ordersPerMin.data.queryTime;
          this.kpis.itemsPerMinute = itemsPerMin.data.itemsPerMinute || 0;
          this.kpis.itemsPerMinQueryTime = itemsPerMin.data.queryTime;
          this.kpis.apiLatency = apiLatency.duration || 0;
          
          // Remove this controller from the list since request completed
          const index = this.abortControllers.indexOf(abortController);
          if (index > -1) {
            this.abortControllers.splice(index, 1);
          }
        } catch (error) {
          if (error.name === 'CanceledError' || error.name === 'AbortError' || axios.isCancel(error)) {
            // Request was cancelled, ignore the error
            return;
          }
          console.error('Error loading KPIs:', error);
          
          // Remove this controller from the list
          const index = this.abortControllers.indexOf(abortController);
          if (index > -1) {
            this.abortControllers.splice(index, 1);
          }
        }
      };

      // Update immediately and then every 3 seconds
      updateKPIs();
      this.pollingInterval = setInterval(updateKPIs, 3000);
    },
    formatNumber(num, decimals = 0) {
      return new Intl.NumberFormat('en-US', {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals
      }).format(num);
    },
    async refreshRegionData() {
      if (this.isRefreshingRegion) {
        return;
      }
      
      this.isRefreshingRegion = true;
      
      // Create abort controller for this request
      const abortController = new AbortController();
      this.abortControllers.push(abortController);
      
      try {
        const response = await axios.get(this.getApiUrl('/api/stats/by-region'), { signal: abortController.signal });
        this.regionData = response.data.data || response.data;
        this.regionQueryTime = response.data.queryTime;
        
        // Remove this controller from the list since request completed
        const index = this.abortControllers.indexOf(abortController);
        if (index > -1) {
          this.abortControllers.splice(index, 1);
        }
      } catch (error) {
        if (error.name === 'CanceledError' || error.name === 'AbortError' || axios.isCancel(error)) {
          // Request was cancelled, ignore the error
          return;
        }
        console.error('Error refreshing region data:', error);
        
        // Remove this controller from the list
        const index = this.abortControllers.indexOf(abortController);
        if (index > -1) {
          this.abortControllers.splice(index, 1);
        }
      } finally {
        this.isRefreshingRegion = false;
      }
    },
    async refreshProductData() {
      if (this.isRefreshingProduct) {
        return;
      }
      
      this.isRefreshingProduct = true;
      
      // Create abort controller for this request
      const abortController = new AbortController();
      this.abortControllers.push(abortController);
      
      try {
        const response = await axios.get(this.getApiUrl('/api/stats/by-product'), { signal: abortController.signal });
        this.productData = response.data.data || response.data;
        this.productQueryTime = response.data.queryTime;
        
        // Remove this controller from the list since request completed
        const index = this.abortControllers.indexOf(abortController);
        if (index > -1) {
          this.abortControllers.splice(index, 1);
        }
      } catch (error) {
        if (error.name === 'CanceledError' || error.name === 'AbortError' || axios.isCancel(error)) {
          // Request was cancelled, ignore the error
          return;
        }
        console.error('Error refreshing product data:', error);
        
        // Remove this controller from the list
        const index = this.abortControllers.indexOf(abortController);
        if (index > -1) {
          this.abortControllers.splice(index, 1);
        }
      } finally {
        this.isRefreshingProduct = false;
      }
    },
    formatDate(dateString) {
      if (!dateString) return '';
      try {
        // Handle date strings that might be in YYYY-MM-DD format
        // The database returns DATE() as a string in YYYY-MM-DD format
        let date;
        if (typeof dateString === 'string') {
          // Parse YYYY-MM-DD format directly (most common from database)
          const parts = dateString.split('-');
          if (parts.length === 3) {
            const year = parseInt(parts[0], 10);
            const month = parseInt(parts[1], 10) - 1; // Month is 0-indexed
            const day = parseInt(parts[2], 10);
            date = new Date(year, month, day);
          } else {
            date = new Date(dateString);
          }
        } else if (dateString instanceof Date) {
          date = dateString;
        } else {
          // If it's an object, try to extract date value
          console.warn('Date is not a string or Date object:', dateString);
          return String(dateString); // Return as string
        }
        
        if (isNaN(date.getTime())) {
          console.warn('Invalid date:', dateString);
          return String(dateString); // Return as string if can't parse
        }
        
        // Format as "Dec 4" style
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      } catch (error) {
        console.error('Error formatting date:', dateString, error);
        return String(dateString); // Return as string on error
      }
    }
  }
};
</script>

<style scoped>
.dashboard {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1.5rem;
}

.charts-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
  gap: 2rem;
}

.chart-card {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.chart-card.full-width {
  grid-column: 1 / -1;
}

.chart-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.chart-card h2 {
  margin: 0;
  color: #333;
  font-size: 1.25rem;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.query-time {
  font-size: 0.75rem;
  color: #999;
  font-weight: 500;
  white-space: nowrap;
}

.range-control {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.range-control label {
  font-size: 0.875rem;
  color: #666;
  font-weight: 500;
  min-width: 60px;
}

.range-slider {
  width: 200px;
  height: 6px;
  border-radius: 3px;
  background: #e0e0e0;
  outline: none;
  -webkit-appearance: none;
}

.range-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #667eea;
  cursor: pointer;
}

.range-slider::-moz-range-thumb {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #667eea;
  cursor: pointer;
  border: none;
}

.refresh-button {
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.25rem 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  transition: background-color 0.2s;
}

.refresh-button:hover:not(:disabled) {
  background-color: #f0f0f0;
}

.refresh-button:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.refresh-icon {
  font-size: 1.25rem;
  display: inline-block;
  transition: transform 0.2s;
}

.refresh-icon.spinning {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.loading {
  text-align: center;
  padding: 2rem;
  color: #666;
}
</style>
