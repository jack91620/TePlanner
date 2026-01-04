/**
 * Common utility functions
 */

/**
 * Format duration in minutes to human readable string
 */
function formatDuration(minutes) {
  if (!minutes || minutes <= 0) return '0 min';
  if (minutes < 60) return `${minutes} min`;

  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;

  if (mins === 0) return `${hours}h`;
  return `${hours}h ${mins}m`;
}

/**
 * Format distance based on unit preference
 */
function formatDistance(km, useMiles = false) {
  if (useMiles) {
    const miles = km * 0.621371;
    return `${miles.toFixed(1)} mi`;
  }
  return `${km.toFixed(1)} km`;
}

/**
 * Calculate straight-line distance between two points (Haversine)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

function toRad(deg) {
  return deg * Math.PI / 180;
}

/**
 * Debounce function
 */
function debounce(fn, delay) {
  let timer = null;
  return function(...args) {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      fn.apply(this, args);
    }, delay);
  };
}

/**
 * Throttle function
 */
function throttle(fn, limit) {
  let lastTime = 0;
  return function(...args) {
    const now = Date.now();
    if (now - lastTime >= limit) {
      lastTime = now;
      fn.apply(this, args);
    }
  };
}

module.exports = {
  formatDuration,
  formatDistance,
  calculateDistance,
  debounce,
  throttle
};
