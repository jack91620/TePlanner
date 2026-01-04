/**
 * Mini program configuration
 */

// Environment configurations
const env = {
  development: {
    apiBaseUrl: 'http://localhost:8000/api/v1',
    debug: true
  },
  production: {
    apiBaseUrl: 'https://api.teplanner.com/api/v1',
    debug: false
  }
};

// Current environment (change for production)
const currentEnv = 'development';

module.exports = {
  ...env[currentEnv],

  // Tesla OAuth configuration
  tesla: {
    // OAuth will be handled by backend
  },

  // Map configuration
  map: {
    key: 'YOUR_TENCENT_MAP_KEY' // Replace with actual key
  },

  // App settings
  app: {
    name: 'TePlanner',
    version: '1.0.0'
  }
};
