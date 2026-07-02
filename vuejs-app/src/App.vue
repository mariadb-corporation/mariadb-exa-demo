<template>
  <div id="app">
    <header class="header">
      <div class="header-content">
        <h1>MariaDB Analytics Dashboard</h1>
        <div class="database-toggle">
          <span class="toggle-label" :class="{ active: !useExa }">MariaDB</span>
          <label class="switch">
            <input type="checkbox" v-model="useExa" @change="onToggleChange">
            <span class="slider"></span>
          </label>
          <span class="toggle-label" :class="{ active: useExa, 'exa-active': useExa }">MariaDB Exa</span>
        </div>
      </div>
    </header>
    <main class="main-content">
      <Dashboard :use-exa="useExa" />
    </main>
  </div>
</template>

<script>
import Dashboard from './components/Dashboard.vue';

export default {
  name: 'App',
  components: {
    Dashboard
  },
  data() {
    return {
      useExa: false
    };
  },
  mounted() {
    // Read from URL parameter
    const urlParams = new URLSearchParams(window.location.search);
    this.useExa = urlParams.get('exa') === 'true';
  },
  methods: {
    onToggleChange() {
      // Update URL parameter without page reload
      const url = new URL(window.location);
      if (this.useExa) {
        url.searchParams.set('exa', 'true');
      } else {
        url.searchParams.delete('exa');
      }
      window.history.pushState({}, '', url);
      
      // Emit event to Dashboard to reload data
      this.$nextTick(() => {
        window.dispatchEvent(new Event('database-changed'));
      });
    }
  }
};
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background-color: #f5f5f5;
}

#app {
  min-height: 100vh;
}

.header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2rem;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  max-width: 1400px;
  margin: 0 auto;
}

.header h1 {
  font-size: 2rem;
  font-weight: 600;
  margin: 0;
}

.database-toggle {
  display: flex;
  align-items: center;
  gap: 1rem;
  background: rgba(255, 255, 255, 0.1);
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  backdrop-filter: blur(10px);
}

.toggle-label {
  font-size: 0.9rem;
  font-weight: 500;
  opacity: 0.7;
  transition: opacity 0.3s;
}

.toggle-label.active {
  opacity: 1;
  font-weight: 600;
}

.toggle-label.exa-active {
  font-size: 1.1rem;
  color: #4caf50;
}

.switch {
  position: relative;
  display: inline-block;
  width: 50px;
  height: 26px;
}

.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(255, 255, 255, 0.3);
  transition: 0.4s;
  border-radius: 26px;
}

.slider:before {
  position: absolute;
  content: "";
  height: 20px;
  width: 20px;
  left: 3px;
  bottom: 3px;
  background-color: white;
  transition: 0.4s;
  border-radius: 50%;
}

input:checked + .slider {
  background-color: rgba(255, 255, 255, 0.5);
}

input:checked + .slider:before {
  transform: translateX(24px);
}

.database-indicator {
  font-size: 0.85rem;
  font-weight: 600;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.2);
  margin-left: 0.5rem;
}

.database-indicator.exa-active {
  background: rgba(76, 175, 80, 0.3);
}

.main-content {
  max-width: 1400px;
  margin: 0 auto;
  padding: 2rem;
}
</style>

