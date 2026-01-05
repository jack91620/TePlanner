// pages/index/index.js

const app = getApp();

Page({
  data: {
    hasVehicle: false,
    vehicle: null,
    vehicleState: null,
    origin: null,
    destination: null,
    currentSoc: 80,
    recentTrips: [],
    canPlan: false,
    loading: false,
    showVehicleCard: true
  },

  onLoad() {
    this.loadRecentTrips();
  },

  async onShow() {
    // Check login and vehicle status
    await this.initializeState();
  },

  async initializeState() {
    const token = wx.getStorageSync('token');

    if (!token) {
      // Not logged in
      this.setData({
        hasVehicle: false,
        vehicle: null,
        vehicleState: null
      });
      return;
    }

    // Check Tesla binding status
    const hasTesla = await app.checkTeslaStatus();

    if (hasTesla) {
      // Fetch vehicle list
      const vehicles = await app.fetchVehicles();

      if (vehicles.length > 0) {
        const vehicle = vehicles[0];
        this.setData({
          hasVehicle: true,
          vehicle: vehicle
        });

        // Try to get vehicle state (might be asleep)
        await this.fetchVehicleState(vehicle.id);
      } else {
        this.setData({
          hasVehicle: true,
          vehicle: null
        });
      }
    } else {
      this.setData({
        hasVehicle: false,
        vehicle: null
      });
    }

    this.updateCanPlan();
  },

  async fetchVehicleState(vehicleId) {
    const token = wx.getStorageSync('token');
    if (!token) return;

    return new Promise((resolve) => {
      wx.request({
        url: `${app.globalData.apiBaseUrl}/vehicles/${vehicleId}/state`,
        method: 'GET',
        header: {
          'Authorization': `Bearer ${token}`
        },
        success: (res) => {
          if (res.statusCode === 200) {
            const state = res.data;
            this.setData({
              vehicleState: state,
              currentSoc: state.battery_level || 80
            });

            // If we have location, set as origin
            if (state.latitude && state.longitude) {
              this.setVehicleAsOrigin(state);
            }
          } else if (res.statusCode === 503) {
            // Vehicle offline
            this.setData({
              vehicleState: { state: 'offline' }
            });
          }
          resolve();
        },
        fail: () => resolve()
      });
    });
  },

  setVehicleAsOrigin(state) {
    // Reverse geocode the vehicle location
    wx.request({
      url: `${app.globalData.apiBaseUrl}/routes/reverse-geocode`,
      method: 'POST',
      data: {
        latitude: state.latitude,
        longitude: state.longitude
      },
      success: (res) => {
        if (res.statusCode === 200) {
          this.setData({
            origin: {
              name: res.data.address || 'Vehicle Location',
              latitude: state.latitude,
              longitude: state.longitude
            }
          });
          this.updateCanPlan();
        }
      }
    });
  },

  async wakeVehicle() {
    const { vehicle } = this.data;
    if (!vehicle) return;

    const token = wx.getStorageSync('token');
    if (!token) return;

    wx.showLoading({ title: 'Waking vehicle...' });

    wx.request({
      url: `${app.globalData.apiBaseUrl}/vehicles/${vehicle.id}/wake`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`
      },
      success: (res) => {
        wx.hideLoading();
        if (res.statusCode === 200) {
          wx.showToast({
            title: res.data.message,
            icon: 'success'
          });

          // Retry fetching state after a delay
          setTimeout(() => {
            this.fetchVehicleState(vehicle.id);
          }, 5000);
        } else {
          wx.showToast({
            title: 'Failed to wake vehicle',
            icon: 'none'
          });
        }
      },
      fail: () => {
        wx.hideLoading();
        wx.showToast({
          title: 'Network error',
          icon: 'none'
        });
      }
    });
  },

  loadRecentTrips() {
    const trips = wx.getStorageSync('recentTrips') || [];
    this.setData({ recentTrips: trips.slice(0, 5) });
  },

  goToBindVehicle() {
    const token = wx.getStorageSync('token');

    if (!token) {
      // Need to login first
      app.login().then(() => {
        wx.navigateTo({
          url: '/pages/vehicle-binding/vehicle-binding'
        });
      }).catch(() => {
        wx.showToast({
          title: 'Please login first',
          icon: 'none'
        });
      });
    } else {
      wx.navigateTo({
        url: '/pages/vehicle-binding/vehicle-binding'
      });
    }
  },

  chooseOrigin() {
    wx.chooseLocation({
      success: (res) => {
        this.setData({
          origin: {
            name: res.name || res.address,
            latitude: res.latitude,
            longitude: res.longitude
          }
        });
        this.updateCanPlan();
      }
    });
  },

  chooseDestination() {
    wx.chooseLocation({
      success: (res) => {
        this.setData({
          destination: {
            name: res.name || res.address,
            latitude: res.latitude,
            longitude: res.longitude
          }
        });
        this.updateCanPlan();
      }
    });
  },

  useCurrentLocation() {
    wx.getLocation({
      type: 'gcj02',
      success: (res) => {
        this.reverseGeocode(res.latitude, res.longitude);
      },
      fail: () => {
        wx.showToast({
          title: 'Failed to get location',
          icon: 'none'
        });
      }
    });
  },

  useVehicleLocation() {
    const { vehicleState } = this.data;
    if (vehicleState && vehicleState.latitude && vehicleState.longitude) {
      this.setVehicleAsOrigin(vehicleState);
    } else {
      wx.showToast({
        title: 'Vehicle location not available',
        icon: 'none'
      });
    }
  },

  reverseGeocode(latitude, longitude) {
    wx.request({
      url: `${app.globalData.apiBaseUrl}/routes/reverse-geocode`,
      method: 'POST',
      data: { latitude, longitude },
      success: (res) => {
        if (res.statusCode === 200) {
          this.setData({
            origin: {
              name: res.data.address || 'Current Location',
              latitude,
              longitude
            }
          });
          this.updateCanPlan();
        }
      },
      fail: () => {
        this.setData({
          origin: {
            name: 'Current Location',
            latitude,
            longitude
          }
        });
        this.updateCanPlan();
      }
    });
  },

  onSocChange(e) {
    this.setData({ currentSoc: e.detail.value });
  },

  updateCanPlan() {
    const { origin, destination } = this.data;
    this.setData({
      canPlan: !!(origin && destination)
    });
  },

  planRoute() {
    const { origin, destination, currentSoc, vehicle } = this.data;

    if (!origin || !destination) {
      wx.showToast({
        title: 'Please select locations',
        icon: 'none'
      });
      return;
    }

    this.setData({ loading: true });
    wx.showLoading({ title: 'Planning route...' });

    const token = wx.getStorageSync('token');

    wx.request({
      url: `${app.globalData.apiBaseUrl}/routes/plan`,
      method: 'POST',
      header: {
        'Authorization': token ? `Bearer ${token}` : '',
        'Content-Type': 'application/json'
      },
      data: {
        origin: {
          latitude: origin.latitude,
          longitude: origin.longitude,
          address: origin.name
        },
        destination: {
          latitude: destination.latitude,
          longitude: destination.longitude,
          address: destination.name
        },
        current_soc: currentSoc,
        vehicle_id: vehicle ? vehicle.id : null,
        car_type: vehicle ? this.getCarType(vehicle.model) : 'model_y_long_range'
      },
      success: (res) => {
        wx.hideLoading();
        this.setData({ loading: false });

        if (res.statusCode === 200) {
          // Save to recent trips
          this.saveToRecentTrips(origin, destination, res.data);

          // Navigate to result page
          wx.navigateTo({
            url: `/pages/route-result/route-result?data=${encodeURIComponent(JSON.stringify(res.data))}`
          });
        } else {
          wx.showToast({
            title: res.data.detail || 'Planning failed',
            icon: 'none'
          });
        }
      },
      fail: () => {
        wx.hideLoading();
        this.setData({ loading: false });
        wx.showToast({
          title: 'Network error',
          icon: 'none'
        });
      }
    });
  },

  getCarType(model) {
    const modelMap = {
      'Model Y': 'model_y_long_range',
      'Model 3': 'model_3_long_range',
      'Model S': 'model_s_long_range',
      'Model X': 'model_x_long_range'
    };
    return modelMap[model] || 'model_y_long_range';
  },

  saveToRecentTrips(origin, destination, routeData) {
    const trips = wx.getStorageSync('recentTrips') || [];
    const newTrip = {
      id: Date.now(),
      originName: origin.name,
      destinationName: destination.name,
      distanceKm: routeData.total_distance_km,
      origin,
      destination
    };

    // Add to beginning, keep max 10
    trips.unshift(newTrip);
    if (trips.length > 10) trips.pop();

    wx.setStorageSync('recentTrips', trips);
    this.setData({ recentTrips: trips.slice(0, 5) });
  },

  loadTrip(e) {
    const trip = e.currentTarget.dataset.trip;
    this.setData({
      origin: trip.origin,
      destination: trip.destination
    });
    this.updateCanPlan();
  },

  swapLocations() {
    const { origin, destination } = this.data;
    if (origin && destination) {
      this.setData({
        origin: destination,
        destination: origin
      });
    }
  },

  toggleVehicleCard() {
    this.setData({
      showVehicleCard: !this.data.showVehicleCard
    });
  },

  onPullDownRefresh() {
    this.initializeState().then(() => {
      wx.stopPullDownRefresh();
    });
  }
});
