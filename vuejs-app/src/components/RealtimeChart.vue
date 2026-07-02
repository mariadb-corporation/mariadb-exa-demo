<template>
  <div class="realtime-wrapper">

    <!-- KPI ROW -->
    <div class="kpi-row">
      <div class="kpi-card">
        <div class="kpi-label">Current Second Orders</div>
        <div class="kpi-value">{{ currentSecond.order_count || 0 }}</div>
      </div>

      <div class="kpi-card">
        <div class="kpi-label">Current Second Revenue</div>
        <div class="kpi-value">
          ${{ formatNumber(currentSecond.revenue || 0) }}
        </div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Query Time</div>
        <div class="kpi-value">{{ queryTime }}ms</div>
      </div>
    </div>

    <!-- BAR CHART -->
    <h2>Realtime Sales & Revenue (Last 5 Minutes)</h2>
    <div class="chart-container">
      <canvas ref="chartCanvas"></canvas>
    </div>

  </div>
</template>

<script>
import {
  Chart,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
} from 'chart.js'

Chart.register(  
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
)

export default {
  name: "RealtimeChart",
  props: {
    secondlyData: {
      type: Array,
      default: () => [{ second: 0, order_count: 0, revenue: 0 }]
    },
    currentSecond: {
      type: Object,
      default: () => ({ order_count: 0, revenue: 0 })
    },
    queryTime: {
      type: Number,
      default: 0
    }
  },

  data() {
    return {
      chart: null,
      updatePending: false,
      maxOrders: 200
    };
  },

  mounted() {
    this.initChart();
  },
  unmounted() {
    if (this.chart) {
      this.chart.destroy();
    }
  },
  beforeUnmount() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },

  watch: {
    secondlyData: {
      deep: true,
      handler() {
        this.queueUpdate();
      }
    }
  },
  methods: {
    initChart() {
      const canvas = this.$refs.chartCanvas
      if (!canvas) {
        console.warn('RealtimeChart: canvas not found')
        return
      }
      const ctx = canvas.getContext('2d')
      if (!ctx) {
        console.warn('RealtimeChart: 2D context not available')
        return
      }

      const chartObj = new Chart(ctx, {
        type: 'line',
        data: {
          labels: [],
          datasets: [
            {
              label: "Orders / sec",
              backgroundColor: "rgba(66,133,244,.7)",
              borderColor: "#4285F4",
              data: [],
              yAxisID: "y",
              tension: 0.2,
              pointRadius: 0
            },
            {
              label: "Revenue / sec ($)",
              backgroundColor: "rgba(234,67,53,.7)",
              borderColor: "#EA4335",
              data: [],
              yAxisID: "y1",
              tension: 0.2,
              pointRadius: 0
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: false,
          interaction: {
            mode: 'index',
            intersect: false
          },
          scales: {
            x: { ticks:{ maxTicksLimit:30 } },
            y: { beginAtZero:true, title:{ display:true, text:"Orders" }},
            y1: {
              beginAtZero:true,
              position:"right",
              grid:{ drawOnChartArea:false },
              title:{ display:true, text:"Revenue ($)" },
            },
          },
          plugins: {
            legend: {
              display: true,
              position: 'top',
              fullSize: true
            },
            title: { display: false },
            tooltip: { enabled: true }
          }
          
        }
      });
      Object.seal(chartObj);
      this.chart = chartObj;  

      // console.log("chart", this.chart);
      // console.log("updatePending", this.updatePending);
      // console.log("Starting chart with", this.secondlyData.length, "points");
      
      if (this.secondlyData.length > 0) this.queueUpdate();
    },

    queueUpdate() {
      if (this.updatePending) {
        return;
      }
      this.updatePending = true;
      this.updateChart();
      this.updatePending = false;

    },
    updateChart() {
      if (!this.chart || this.secondlyData.length < 1) {
         this.updatePending = false;
         return;
      }
      const labels = [];
      const orders = [];
      const revenue = [];

      // ONE LOOP populating all arrays
      for (const point of this.secondlyData) {
        if (!point?.second) continue;
        if (Number(point.order_count) > this.maxOrders) {
          this.maxOrders= Number(point.order_count);
        }
        const d = new Date(point.second);
        const formatted = isNaN(d)
          ? point.second                      // fallback if second is number or invalid date
          : d.toLocaleTimeString('en-US', {   // 12:30:22 format
              hour: '2-digit',
              minute: '2-digit',
              second: '2-digit',
              hour12: true
            }).replace(/\s?(AM|PM)$/i, '');    // <-- remove AM/PM

        labels.push(formatted);
        orders.push(Number(point.order_count) || 0);
        revenue.push(Number(point.revenue) || 0);
      }

      // console.log("labels:", labels.length);
      // console.log("orders:", orders.length);
      // console.log("revenue:", revenue.length);

      this.chart.data.labels = labels;
      this.chart.data.datasets[0].data = orders;
      this.chart.data.datasets[1].data = revenue; 
      this.chart.options.scales.y.max = this.maxOrders;


      try {
        this.chart.resize();
        this.chart.update();
        this.updatePending = false;
      } catch (error) {
        console.error("Error in updateChart: ", error);
        this.updatePending = false;
      }
    },

    formatNumber(num) {
      return Number(num).toLocaleString(undefined,{ minimumFractionDigits:2, maximumFractionDigits:2 });
    }
  }
}
</script>

<style scoped>
.realtime-wrapper {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* KPI cards */
.kpi-row {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.kpi-card {
  flex:1;
  min-width:200px;
  padding:1rem;
  background:#f8f9fa;
  border-radius:8px;
  text-align:center;
  box-shadow:0 2px 6px rgba(0,0,0,.06);
}

.kpi-label {
  font-size:.8rem;
  text-transform:uppercase;
  color:#666;
  margin-bottom:.25rem
}

.kpi-value {
  font-size:1.7rem;
  font-weight:700;
  color:#111;
}

/* Chart */
.chart-container {
  height:350px;
  width:100%;
  background:white;
  border-radius:8px;
  padding:.5rem 1rem;
  box-shadow:0 2px 6px rgba(0,0,0,.08);
}
</style>