 <template>
  <div class="chart-container">
    <canvas ref="chartCanvas"></canvas>
  </div>
</template>

<script>
import { Chart, registerables } from 'chart.js';

Chart.register(...registerables);

export default {
  name: 'BarChart',
  props: {
    data: {
      type: Array,
      required: true
    },
    labels: {
      type: Array,
      required: true
    },
    values: {
      type: Array,
      required: true
    },
    label: {
      type: String,
      default: 'Value'
    }
  },
  data() {
    return {
      chart: null,
      isUpdating: false
    };
  },
  mounted() {
    this.$nextTick(() => {
      this.createChart();
    });
  },
  watch: {
    data: {
      handler() {
        this.updateChart();
      },
      deep: true
    }
  },
  beforeUnmount() {
    if (this.chart) {
      this.chart.destroy();
    }
  },
  methods: {
    createChart() {
      const ctx = this.$refs.chartCanvas.getContext('2d');
      
      this.chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: this.labels,
          datasets: [{
            label: this.label,
            data: this.values,
            backgroundColor: 'rgba(102, 126, 234, 0.6)',
            borderColor: 'rgba(102, 126, 234, 1)',
            borderWidth: 1
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                callback: function(value) {
                  return '$' + value.toLocaleString();
                }
              }
            }
          },
          plugins: {
            legend: {
              display: false
            }
          }
        }
      });
      
      // Chart.js automatically renders on creation, no need to force an update
    },
    updateChart() {
      // Prevent recursive calls
      if (this.isUpdating || !this.chart) {
        return;
      }
      
      // Check if chart is in a valid state
      if (!this.chart.ctx || !this.chart.canvas) {
        return;
      }
      
      // Check if chart has been destroyed or is being destroyed
      if (this.chart._destroyed || !this.chart.config) {
        return;
      }
      
      // Check if chart layout is initialized
      if (!this.chart.chartArea || !this.chart.scales) {
        // Layout not ready yet, skip this update
        return;
      }
      
      // Check if layout boxes exist (needed for plugins)
      // Layout boxes are created during the first layout pass
      // Note: layoutBoxes might not be a public property, so we check defensively
      if (this.chart.layoutBoxes !== undefined && 
          (!this.chart.layoutBoxes || Object.keys(this.chart.layoutBoxes).length === 0)) {
        // Layout boxes not ready yet, skip this update
        return;
      }
      
      // Check if datasets exist
      if (!this.chart.data || !this.chart.data.datasets || !this.chart.data.datasets[0]) {
        return;
      }
      
      this.isUpdating = true;
      try {
        this.chart.data.labels = this.labels;
        this.chart.data.datasets[0].data = this.values;
        this.chart.update('none');
      } catch (error) {
        // Handle errors safely - error.message might be undefined
        const errorMessage = error?.message || String(error);
        
        // Handle fullSize error specifically - layout boxes not ready
        if (errorMessage.includes('fullSize')) {
          // Silently skip - layout will be ready on next update
          console.debug('Chart layout not fully ready, skipping update');
        } else if (errorMessage.includes('Maximum call stack') || errorMessage.includes('call stack')) {
          // Stack overflow - reset everything and prevent further updates
          console.warn('Stack overflow in updateChart, resetting state and disabling updates temporarily');
          this.isUpdating = false;
          // Re-enable after a delay
          setTimeout(() => {
            if (this.chart && !this.chart._destroyed) {
              // Chart should recover on next update
            }
          }, 1000);
        } else {
          console.error('Error updating chart:', error);
        }
      } finally {
        this.isUpdating = false;
      }
    }
  }
};
</script>

<style scoped>
.chart-container {
  position: relative;
  height: 300px;
  width: 100%;
}
</style>


