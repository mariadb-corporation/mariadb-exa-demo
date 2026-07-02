<template>
  <div class="chart-container">
    <canvas ref="chartCanvas"></canvas>
  </div>
</template>

<script>
import { Chart, registerables } from 'chart.js';

Chart.register(...registerables);

export default {
  name: 'LineChart',
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
      isDestroyed: false,
      isChartReady: false,
      updatePending: false,
      isUpdating: false
    };
  },
  mounted() {
    this.$nextTick(() => {
      if (this.$refs.chartCanvas) {
        this.createChart();
      }
    });
  },
  watch: {
    data: {
      handler() {
        if (this.isChartReady && !this.isDestroyed && this.chart && !this.chart._destroyed) {
          this.scheduleUpdate();
        }
      },
      deep: true
    },
    labels: {
      handler() {
        if (this.isChartReady && !this.isDestroyed && this.chart && !this.chart._destroyed) {
          this.scheduleUpdate();
        }
      }
    },
    values: {
      handler() {
        if (this.isChartReady && !this.isDestroyed && this.chart && !this.chart._destroyed) {
          this.scheduleUpdate();
        }
      }
    }
  },
  beforeUnmount() {
    this.isDestroyed = true;
    this.isChartReady = false;
    this.updatePending = false;
    if (this.chart) {
      try {
        this.chart.destroy();
      } catch (e) {
        // Ignore destroy errors
      }
      this.chart = null;
    }
  },
  methods: {
    createChart() {
      const ctx = this.$refs.chartCanvas.getContext('2d');
      
      // Ensure labels are strings
      const stringLabels = Array.isArray(this.labels) 
        ? this.labels.map(l => String(l || ''))
        : [];
      
        // Ensure values are numbers
        const numberValues = Array.isArray(this.values)
        ? this.values.map(v => {
            const num = Number(v) || 0;
            return num;
          })
        : [];
        
    
      const chartObj = new Chart(ctx, {
        type: 'line',
        data: {
          labels: stringLabels,
          datasets: [{
            label: this.label,
            data: numberValues,
            borderColor: 'rgba(102, 126, 234, 1)',
            backgroundColor: 'rgba(102, 126, 234, 0.1)',
            borderWidth: 2,
            fill: true,
            tension: 0.4,
            // Show each data point as a distinct dot - make sure all points are visible
            pointRadius: 6,
            pointHoverRadius: 8,
            pointBackgroundColor: 'rgba(102, 126, 234, 1)',
            pointBorderColor: '#ffffff',
            pointBorderWidth: 2,
            pointStyle: 'circle',
            showLine: true,  // Keep the line to show trend, but each point is distinct
            // Ensure points are always shown, even when overlapping
            pointHitRadius: 10
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: false, // Disable animations to prevent state issues
          scales: {
            x: {
              display: true,
              title: {
                display: true,
                text: 'Date'
              },
              ticks: {
                maxRotation: 45,
                minRotation: 45
              }
            },
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Revenue ($)'
              },
              ticks: {
                callback: function(value) {
                  return '$' + value.toLocaleString();
                }
              }
            }
          },
          plugins: {
            legend: {
              display: false,
              fullSize: false  // Prevent fullSize error
            },
            tooltip: {
              callbacks: {
                label: function(context) {
                  // Safely handle tooltip label
                  if (context?.parsed?.y !== null && context?.parsed?.y !== undefined) {
                    const value = Number(context.parsed.y) || 0;
                    return '$' + value.toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    });
                  }
                  return '$0.00';
                }
              }
            }
          },
          interaction: {
            intersect: false,
            mode: 'index'
          }
        }
      });
      Object.seal(chartObj);
      this.chart = chartObj; 
      
      // Chart.js automatically renders on creation
      // Mark chart as ready after a brief delay to ensure DOM is ready
      this.$nextTick(() => {
        requestAnimationFrame(() => {
          this.isChartReady = true;
          if (this.updatePending) {
            this.updatePending = false;
            this.updateChart();
          }
        });
      });
    },
    scheduleUpdate() {
      if (this.isDestroyed || !this.isChartReady || this.isUpdating) {
        return;
      }
      
      // Use requestAnimationFrame to ensure updates happen at the right time
      if (this.updatePending) {
        return; // Already scheduled
      }
      
      this.updatePending = true;
      requestAnimationFrame(() => {
        this.updatePending = false;
        this.updateChart();
      });
    },
    updateChart() {
      // Prevent recursive calls
      if (this.isUpdating || this.isDestroyed || !this.chart || !this.isChartReady) {
        return;
      }
      
      // Basic validation checks
      if (!this.chart.data || !this.chart.data.datasets || !this.chart.data.datasets[0] ||
          !this.chart.ctx || !this.chart.canvas || this.chart._destroyed) {
        return;
      }
      
      // Check if chart layout is ready to prevent fullSize errors
      if (!this.chart.chartArea || !this.chart.scales) {
        // Try to initialize layout
        try {
          this.chart.update('none');
        } catch (e) {
          // If update fails, layout isn't ready yet
          return;
        }
        // Check again after update
        if (!this.chart.chartArea || !this.chart.scales) {
          return;
        }
      }
      
      this.isUpdating = true;
      
      // Ensure labels and values are arrays
      if (!Array.isArray(this.labels) || !Array.isArray(this.values)) {
        return;
      }
      
      try {
        // Ensure labels are strings, not objects
        const stringLabels = this.labels.map(label => {
          if (typeof label === 'string') return label;
          if (label && typeof label === 'object') {
            // If it's a date object, convert to string
            if (label instanceof Date) {
              return label.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
            }
            return String(label);
          }
          return String(label || '');
        });
        
        // Ensure values are numbers
        const numberValues = this.values.map(val => Number(val) || 0);
        
        // Only update if we have valid data
        if (stringLabels.length > 0 && numberValues.length > 0) {
          // Check if data actually changed to avoid unnecessary updates
          const currentLabels = this.chart.data.labels || [];
          const currentData = this.chart.data.datasets[0].data || [];
          
          const labelsChanged = JSON.stringify(currentLabels) !== JSON.stringify(stringLabels);
          const dataChanged = JSON.stringify(currentData) !== JSON.stringify(numberValues);
          
          if (labelsChanged || dataChanged) {
            this.chart.data.labels = stringLabels;
            this.chart.data.datasets[0].data = numberValues;
            this.chart.data.datasets[0].label = this.label || 'Value';
            
            // Update chart without animation, with error handling for fullSize
            try {
              // Ensure layout is ready before updating
              if (this.chart.chartArea && this.chart.scales) {
                this.chart.update('none');
              } else {
                // Force layout initialization
                this.chart.resize();
                this.chart.update('none');
              }
            } catch (updateError) {
              // Handle fullSize errors gracefully
              if (updateError?.message?.includes('fullSize')) {
                console.debug('Chart layout not ready, will retry on next update');
                // Retry after a brief delay
                setTimeout(() => {
                  if (this.chart && !this.chart._destroyed && this.chart.chartArea) {
                    try {
                      this.chart.update('none');
                    } catch (e) {
                      console.error('Error retrying chart update:', e);
                    }
                  }
                }, 100);
              } else {
                console.error('Error in chart.update:', updateError);
              }
            }
          }
        } else if (stringLabels.length === 0 && numberValues.length === 0) {
          // Clear chart if no data
          this.chart.data.labels = [];
          this.chart.data.datasets[0].data = [];
          try {
            if (this.chart.chartArea && this.chart.scales) {
              this.chart.update('none');
            }
          } catch (updateError) {
            console.error('Error clearing chart:', updateError);
          }
        }
      } catch (error) {
        // Handle errors safely - error.message might be undefined
        const errorMessage = error?.message || String(error);
        
        // Handle fullSize error specifically - layout boxes not ready
        if (errorMessage.includes('fullSize')) {
          // Silently skip - layout will be ready on next update
        } else if (errorMessage.includes('Maximum call stack') || errorMessage.includes('call stack')) {
          // Stack overflow - reset everything and prevent further updates
          this.isUpdating = false;
          this.isChartReady = false;
          // Re-enable after a delay
          setTimeout(() => {
            if (this.chart && !this.chart._destroyed) {
              this.isChartReady = true;
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

