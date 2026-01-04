// pages/index/index.js

const app = getApp();

Page({
  data: {
    hasVehicle: false,
    vehicle: null,
    origin: null,
    destination: null,
    currentSoc: 80,
    recentTrips: [],
    canPlan: false
  },

  onLoad() {
    this.checkVehicleStatus();
    this.loadRecentTrips();
  },

  onShow() {
    // Refresh vehicle status when page shows
    if (app.globalData.hasVehicleBound) {
      this.refreshVehicleStatus();
    }
  },

  checkVehicleStatus() {
    const hasVehicle = app.globalData.hasVehicleBound;
    this.setData({
      hasVehicle,
      vehicle: app.globalData.currentVehicle
    });
    this.updateCanPlan();
  },

  refreshVehicleStatus() {
    const token = wx.getStorageSync('token');
    if (!token) return;

    wx.request({
      url: `${app.globalData.apiBaseUrl}/vehicles/current/status`,
      method: 'GET',
      header: {
        'Authorization': `Bearer ${token}`
      },
      success: (res) => {
        if (res.statusCode === 200) {
          const vehicle = res.data;
          app.globalData.currentVehicle = vehicle;
          this.setData({
            hasVehicle: true,
            vehicle,
            currentSoc: vehicle.batteryLevel || 80
          });
          this.updateCanPlan();
        }
      }
    });
  },

  loadRecentTrips() {
    const trips = wx.getStorageSync('recentTrips') || [];
    this.setData({ recentTrips: trips.slice(0, 5) });
  },

  goToBindVehicle() {
    wx.navigateTo({
      url: '/pages/vehicle-binding/vehicle-binding'
    });
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
        // Reverse geocode to get address
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

  reverseGeocode(latitude, longitude) {
    // Use Tencent Map API for reverse geocoding
    wx.request({
      url: `${app.globalData.apiBaseUrl}/map/reverse-geocode`,
      method: 'GET',
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
        // Fallback to generic name
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

    wx.showLoading({ title: 'Planning...' });

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
          name: origin.name,
          latitude: origin.latitude,
          longitude: origin.longitude
        },
        destination: {
          name: destination.name,
          latitude: destination.latitude,
          longitude: destination.longitude
        },
        initial_soc: vehicle ? vehicle.batteryLevel : currentSoc,
        vehicle_id: vehicle ? vehicle.id : null
      },
      success: (res) => {
        wx.hideLoading();
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
        wx.showToast({
          title: 'Network error',
          icon: 'none'
        });
      }
    });
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
  }
});
