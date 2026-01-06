/**
 * API utility functions for TePlanner
 */

const app = getApp();

/**
 * Make authenticated API request
 */
function request(options) {
  return new Promise((resolve, reject) => {
    const token = wx.getStorageSync('token');

    wx.request({
      url: `${app.globalData.apiBaseUrl}${options.url}`,
      method: options.method || 'GET',
      data: options.data,
      header: {
        'Authorization': token ? `Bearer ${token}` : '',
        'Content-Type': 'application/json',
        ...options.header
      },
      success: (res) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(res.data);
        } else if (res.statusCode === 401) {
          // Token expired, clear and redirect to login
          wx.removeStorageSync('token');
          wx.removeStorageSync('tesla_token');
          app.globalData.userInfo = null;
          app.globalData.hasVehicleBound = false;
          reject(new Error('Unauthorized'));
        } else {
          reject(new Error(res.data.detail || 'Request failed'));
        }
      },
      fail: (err) => {
        reject(new Error(err.errMsg || 'Network error'));
      }
    });
  });
}

/**
 * GET request
 */
function get(url, params) {
  return request({
    url,
    method: 'GET',
    data: params
  });
}

/**
 * POST request
 */
function post(url, data) {
  return request({
    url,
    method: 'POST',
    data
  });
}

/**
 * PUT request
 */
function put(url, data) {
  return request({
    url,
    method: 'PUT',
    data
  });
}

/**
 * DELETE request
 */
function del(url) {
  return request({
    url,
    method: 'DELETE'
  });
}

// ============ Vehicle API ============

/**
 * Get user's Tesla vehicles
 * @returns {Promise<Array>} List of vehicles
 */
function getVehicles() {
  return get('/vehicles/').then(function(res) {
    return res.vehicles || [];
  });
}

/**
 * Get vehicle state (battery, location, etc.)
 * @param {string} vehicleId - Vehicle ID
 * @returns {Promise<Object>} Vehicle state
 */
function getVehicleState(vehicleId) {
  return get('/vehicles/' + vehicleId + '/state');
}

/**
 * Wake up vehicle
 * @param {string} vehicleId - Vehicle ID
 * @returns {Promise<Object>} Wake response
 */
function wakeVehicle(vehicleId) {
  return post('/vehicles/' + vehicleId + '/wake');
}

/**
 * Send navigation to vehicle
 * @param {string} vehicleId - Vehicle ID
 * @param {Object} destination - { latitude, longitude, name? }
 * @returns {Promise<Object>} Response
 */
function sendNavigation(vehicleId, destination) {
  return post('/vehicles/' + vehicleId + '/navigate', {
    latitude: destination.latitude,
    longitude: destination.longitude,
    order: 1
  });
}

// ============ Route Planning API ============

/**
 * Plan a charging route
 * @param {Object} params - { origin, destination, current_soc, vehicle_id }
 * @returns {Promise<Object>} Route plan with charging stops
 */
function planRoute(params) {
  var requestData = {
    destination: {
      latitude: params.destination.latitude,
      longitude: params.destination.longitude,
      address: params.destination.name || params.destination.address
    },
    current_soc: params.current_soc || 80,
    min_arrival_soc: 20
  };

  if (params.origin) {
    requestData.origin = {
      latitude: params.origin.latitude,
      longitude: params.origin.longitude
    };
  }

  if (params.vehicle_id) {
    requestData.vehicle_id = params.vehicle_id;
  }

  return post('/routes/plan', requestData).then(function(res) {
    // Transform response to match frontend expected format
    return {
      route_id: res.route_id,
      origin: res.origin,
      destination: {
        name: res.destination.name || res.destination.address || '',
        latitude: res.destination.lat,
        longitude: res.destination.lng
      },
      total_distance: res.total_distance_km,
      total_duration: formatDuration(res.total_duration_minutes),
      driving_duration: res.driving_duration_minutes,
      charging_duration: res.charging_duration_minutes,
      charging_stops: (res.charging_stops || []).map(function(stop) {
        return {
          id: stop.station_id,
          name: stop.name,
          latitude: stop.latitude,
          longitude: stop.longitude,
          address: stop.address,
          arrival_soc: stop.arrival_soc,
          departure_soc: stop.departure_soc,
          charging_duration: stop.charging_duration_minutes,
          arrival_time: calculateArrivalTime(stop.distance_from_start_km, res.total_distance_km, res.total_duration_minutes)
        };
      }),
      polyline: res.polyline || [],
      arrival_soc: res.arrival_soc,
      initial_soc: res.initial_soc,
      warnings: res.warnings || []
    };
  });
}

/**
 * Geocode address to coordinates
 * @param {string} address - Address string
 * @returns {Promise<Object>} { latitude, longitude, address }
 */
function geocode(address) {
  return post('/routes/geocode', { address: address });
}

/**
 * Reverse geocode coordinates to address
 * @param {number} latitude
 * @param {number} longitude
 * @returns {Promise<Object>} Address info
 */
function reverseGeocode(latitude, longitude) {
  return post('/routes/reverse-geocode?latitude=' + latitude + '&longitude=' + longitude);
}

/**
 * Search places by keyword
 * @param {string} keyword - Search keyword
 * @param {string} location - Center location "lat,lng"
 * @returns {Promise<Array>} List of places
 */
function searchPlaces(keyword, location) {
  return get('/routes/search', {
    keyword: keyword,
    location: location
  }).then(function(res) {
    return (res.results || []).map(function(item) {
      return {
        id: item.id,
        name: item.title || item.name,
        address: item.address,
        latitude: item.location ? item.location.lat : item.latitude,
        longitude: item.location ? item.location.lng : item.longitude,
        distance: item.distance_km ? Math.round(item.distance_km) : item._distance ? Math.round(item._distance / 1000) : null
      };
    });
  });
}

// ============ Charging Stations API ============

/**
 * Get nearby charging stations
 * @param {Object} params - { latitude, longitude, type, radius }
 * @returns {Promise<Array>} List of stations
 */
function getNearbyStations(params) {
  return get('/charging/nearby', {
    latitude: params.latitude,
    longitude: params.longitude,
    type: params.type || 'supercharger',
    radius: params.radius || 50
  }).then(function(res) {
    return res.stations || [];
  }).catch(function() {
    // Return mock data if API not available
    return getMockNearbyStations(params);
  });
}

/**
 * Get charging station details
 * @param {string} stationId - Station ID
 * @returns {Promise<Object>} Station details
 */
function getStationDetail(stationId) {
  return get('/charging/stations/' + stationId);
}

// ============ Auth API ============

/**
 * Check Tesla link status
 * @returns {Promise<Object>} { linked, expired }
 */
function checkTeslaStatus() {
  var userId = wx.getStorageSync('userId');
  if (!userId) {
    return Promise.resolve({ linked: false, expired: false });
  }
  return get('/auth/tesla/status?user_id=' + userId);
}

/**
 * Get Tesla OAuth URL
 * @returns {Promise<Object>} { auth_url }
 */
function getTeslaAuthUrl() {
  var userId = wx.getStorageSync('userId');
  return get('/auth/tesla/authorize?user_id=' + userId);
}

// ============ Helper Functions ============

/**
 * Format duration in minutes to readable string
 */
function formatDuration(minutes) {
  if (!minutes) return '0min';
  var hours = Math.floor(minutes / 60);
  var mins = minutes % 60;
  if (hours > 0) {
    return hours + 'h ' + mins + 'min';
  }
  return mins + 'min';
}

/**
 * Calculate estimated arrival time for a stop
 */
function calculateArrivalTime(distanceFromStart, totalDistance, totalMinutes) {
  if (!totalDistance || !totalMinutes) return '--:--';
  var ratio = distanceFromStart / totalDistance;
  var minutesFromNow = Math.round(ratio * totalMinutes);
  var arrival = new Date(Date.now() + minutesFromNow * 60 * 1000);
  var hours = arrival.getHours().toString().padStart(2, '0');
  var mins = arrival.getMinutes().toString().padStart(2, '0');
  return hours + ':' + mins;
}

/**
 * Mock nearby stations for development
 */
function getMockNearbyStations(params) {
  var baseStations = [
    {
      id: 'sc_001',
      name: 'Tesla Supercharger',
      type: 'supercharger',
      latitude: params.latitude + 0.01,
      longitude: params.longitude + 0.01,
      address: 'Mock Address 1',
      available: 8,
      total: 12,
      power: 250,
      distance: 1.2
    },
    {
      id: 'sc_002',
      name: 'Tesla Supercharger',
      type: 'supercharger',
      latitude: params.latitude - 0.02,
      longitude: params.longitude + 0.02,
      address: 'Mock Address 2',
      available: 4,
      total: 8,
      power: 150,
      distance: 3.5
    }
  ];
  return baseStations;
}

module.exports = {
  // Base methods
  request: request,
  get: get,
  post: post,
  put: put,
  del: del,
  // Vehicle API
  getVehicles: getVehicles,
  getVehicleState: getVehicleState,
  wakeVehicle: wakeVehicle,
  sendNavigation: sendNavigation,
  // Route API
  planRoute: planRoute,
  geocode: geocode,
  reverseGeocode: reverseGeocode,
  searchPlaces: searchPlaces,
  // Charging API
  getNearbyStations: getNearbyStations,
  getStationDetail: getStationDetail,
  // Auth API
  checkTeslaStatus: checkTeslaStatus,
  getTeslaAuthUrl: getTeslaAuthUrl
};
