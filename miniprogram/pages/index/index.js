// Tesla-style Index Page
var app = getApp();
var api = require("../../utils/api");

Page({
  data: {
    pageState: "idle",
    panelState: "half",
    hasVehicle: false,
    vehicle: null,
    vehicleState: null,
    vehicleOffline: false,
    departureSOC: 80,
    mapCenter: { latitude: 39.9042, longitude: 116.4074 },
    mapScale: 14,
    markers: [],
    polylines: [],
    activeTab: "recent",
    nearbyStations: [],
    recentTrips: [],
    activeStationFilter: "supercharger",
    destination: null,
    routeData: null,
    loading: { vehicle: true, stations: false, route: false, waking: false }
  },

  onLoad: function() {
    this.mapCtx = null;
  },

  onShow: function() {
    this.checkVehicleStatus();
  },

  onReady: function() {
    // Map context will be created after vehicle is connected
  },

  initMapContext: function() {
    if (!this.mapCtx) {
      this.mapCtx = wx.createMapContext("mainMap");
    }
  },

  checkVehicleStatus: function() {
    var that = this;
    var token = wx.getStorageSync("token");

    // If no token, show login screen
    if (!token) {
      that.setData({ hasVehicle: false, "loading.vehicle": false });
      return;
    }

    that.setData({ "loading.vehicle": true });

    // Check Tesla link status first
    api.checkTeslaStatus().then(function(status) {
      if (!status.linked || status.expired) {
        that.setData({ hasVehicle: false, "loading.vehicle": false });
        return;
      }

      // Tesla is linked, get vehicles
      return api.getVehicles();
    }).then(function(vehicles) {
      if (!vehicles || vehicles.length === 0) {
        that.setData({ hasVehicle: false, "loading.vehicle": false });
        return;
      }

      var vehicle = vehicles[0];
      that.setData({
        hasVehicle: true,
        vehicle: vehicle,
        "loading.vehicle": false
      });

      // Initialize map and fetch data
      that.initMapContext();
      that.fetchVehicleState(vehicle.id);
      that.loadRecentTrips();

    }).catch(function(err) {
      console.error("Failed to check vehicle status:", err);
      that.setData({ hasVehicle: false, "loading.vehicle": false });
    });
  },

  fetchVehicleState: function(vehicleId) {
    var that = this;

    api.getVehicleState(vehicleId).then(function(state) {
      that.setData({
        vehicleState: state,
        vehicleOffline: false,
        departureSOC: state.battery_level || 80
      });

      if (state.latitude && state.longitude) {
        that.setData({
          mapCenter: { latitude: state.latitude, longitude: state.longitude }
        });
        that.updateVehicleMarker(state);
        that.loadNearbyStations();
      }
    }).catch(function(err) {
      console.error("Failed to get vehicle state:", err);
      var errorMsg = err.message || "";

      // Check if vehicle is offline, auto wake it
      if (errorMsg.indexOf("offline") !== -1 || errorMsg.indexOf("asleep") !== -1) {
        that.setData({ vehicleOffline: true });
        that.wakeAndFetchState(vehicleId);
      } else {
        // Other errors, use device location
        that.initMapFromDevice();
      }
    });
  },

  wakeAndFetchState: function(vehicleId) {
    var that = this;

    that.setData({ "loading.waking": true });
    wx.showLoading({ title: "正在连接车辆..." });

    api.wakeVehicle(vehicleId).then(function() {
      // Wait for vehicle to wake up, then fetch state
      setTimeout(function() {
        api.getVehicleState(vehicleId).then(function(state) {
          wx.hideLoading();
          that.setData({
            vehicleState: state,
            vehicleOffline: false,
            "loading.waking": false,
            departureSOC: state.battery_level || 80
          });

          if (state.latitude && state.longitude) {
            that.setData({
              mapCenter: { latitude: state.latitude, longitude: state.longitude }
            });
            that.updateVehicleMarker(state);
            that.loadNearbyStations();
          }
        }).catch(function(err) {
          wx.hideLoading();
          console.error("Failed to get state after wake:", err);
          that.setData({ "loading.waking": false });
          that.initMapFromDevice();
        });
      }, 3000);
    }).catch(function(err) {
      wx.hideLoading();
      console.error("Failed to wake vehicle:", err);
      that.setData({ "loading.waking": false });
      that.initMapFromDevice();
    });
  },

  initMapFromDevice: function() {
    var that = this;
    wx.getLocation({
      type: "gcj02",
      success: function(res) {
        that.setData({
          mapCenter: { latitude: res.latitude, longitude: res.longitude }
        });
        that.loadNearbyStations();
      },
      fail: function() {
        console.log("Failed to get device location");
      }
    });
  },

  updateVehicleMarker: function(state) {
    var vehicleMarker = {
      id: 1,
      latitude: state.latitude,
      longitude: state.longitude,
      iconPath: "/assets/icons/tesla-car-marker.png",
      width: 40,
      height: 40,
      anchor: { x: 0.5, y: 0.5 },
      rotate: state.heading || 0
    };
    var markers = this.data.markers.filter(function(m) { return m.id !== 1; });
    markers.unshift(vehicleMarker);
    this.setData({ markers: markers });
  },

  loadNearbyStations: function() {
    var that = this;
    var center = this.data.mapCenter;
    var filter = this.data.activeStationFilter;

    that.setData({ "loading.stations": true });

    api.getNearbyStations({
      latitude: center.latitude,
      longitude: center.longitude,
      type: filter,
      radius: 50
    }).then(function(stations) {
      that.setData({ nearbyStations: stations || [] });
      that.updateStationMarkers(stations || []);
    }).catch(function(err) {
      console.error("Failed to load stations:", err);
      that.setData({ nearbyStations: [] });
    }).finally(function() {
      that.setData({ "loading.stations": false });
    });
  },

  updateStationMarkers: function(stations) {
    var that = this;
    var vehicleMarker = this.data.markers.find(function(m) { return m.id === 1; });
    var stationMarkers = stations.map(function(station, index) {
      var iconPath = "/assets/icons/supercharger.png";
      if (station.type === "destination") {
        iconPath = "/assets/icons/destination-charger.png";
      } else if (station.type === "service") {
        iconPath = "/assets/icons/service-center.png";
      }
      return {
        id: 100 + index,
        latitude: station.latitude,
        longitude: station.longitude,
        iconPath: iconPath,
        width: 32,
        height: 32,
        anchor: { x: 0.5, y: 1 },
        callout: {
          content: station.name,
          display: "BYCLICK",
          bgColor: "#242424",
          color: "#ffffff",
          fontSize: 12,
          borderRadius: 8,
          padding: 8
        },
        stationData: station
      };
    });
    var markers = vehicleMarker ? [vehicleMarker].concat(stationMarkers) : stationMarkers;
    that.setData({ markers: markers });
  },

  loadRecentTrips: function() {
    var trips = wx.getStorageSync("recent_trips") || [];
    this.setData({ recentTrips: trips });
  },

  switchTab: function(e) {
    var tab = e.currentTarget.dataset.tab;
    this.setData({ activeTab: tab });
  },

  onFilterChange: function(e) {
    this.setData({ activeStationFilter: e.detail.key || e.detail.filter });
    this.loadNearbyStations();
  },

  onPanelStateChange: function(e) {
    this.setData({ panelState: e.detail.state });
  },

  onSearchTap: function() {
    wx.navigateTo({ url: "/pages/search/search" });
  },

  onStationTap: function(e) {
    var station = e.detail.station;
    this.navigateToStation(station);
  },

  navigateToStation: function(station) {
    this.setData({
      destination: {
        name: station.name,
        latitude: station.latitude,
        longitude: station.longitude,
        address: station.address
      }
    });
    this.planRoute();
  },

  onRecentTap: function(e) {
    var trip = e.currentTarget.dataset.trip;
    this.setData({
      destination: {
        name: trip.destinationName,
        latitude: trip.latitude,
        longitude: trip.longitude,
        address: trip.destinationAddress
      }
    });
    this.planRoute();
  },

  planRoute: function() {
    var that = this;
    var dest = this.data.destination;
    if (!dest) return;

    that.setData({
      "loading.route": true,
      pageState: "route_preview",
      panelState: "half"
    });

    var origin = null;
    if (this.data.vehicleState && this.data.vehicleState.latitude) {
      origin = {
        latitude: this.data.vehicleState.latitude,
        longitude: this.data.vehicleState.longitude
      };
    } else {
      origin = this.data.mapCenter;
    }

    api.planRoute({
      origin: origin,
      destination: dest,
      current_soc: this.data.departureSOC,
      vehicle_id: this.data.vehicle ? this.data.vehicle.id : null
    }).then(function(routeData) {
      that.setData({ routeData: routeData });
      that.drawRoute(routeData);
      that.saveRecentTrip(dest);
    }).catch(function(err) {
      console.error("Failed to plan route:", err);
      wx.showToast({ title: "路线规划失败", icon: "none" });
      that.setData({ pageState: "idle" });
    }).finally(function() {
      that.setData({ "loading.route": false });
    });
  },

  drawRoute: function(routeData) {
    if (!routeData || !routeData.polyline || routeData.polyline.length === 0) {
      // No polyline, just show markers
      this.drawRouteMarkers(routeData);
      return;
    }

    var polyline = {
      points: routeData.polyline,
      color: "#3e6ae1",
      width: 6,
      arrowLine: true
    };

    this.drawRouteMarkers(routeData);
    this.setData({ polylines: [polyline] });

    if (this.mapCtx) {
      this.mapCtx.includePoints({
        points: routeData.polyline,
        padding: [80, 40, 200, 40],
        fail: function() {}
      });
    }
  },

  drawRouteMarkers: function(routeData) {
    var chargingMarkers = (routeData.charging_stops || []).map(function(stop, index) {
      return {
        id: 200 + index,
        latitude: stop.latitude,
        longitude: stop.longitude,
        iconPath: "/assets/icons/charging-marker.png",
        width: 36,
        height: 36,
        anchor: { x: 0.5, y: 1 }
      };
    });

    var destMarker = {
      id: 300,
      latitude: routeData.destination.latitude,
      longitude: routeData.destination.longitude,
      iconPath: "/assets/icons/destination-marker.png",
      width: 36,
      height: 44,
      anchor: { x: 0.5, y: 1 }
    };

    var vehicleMarker = this.data.markers.find(function(m) { return m.id === 1; });
    var markers = vehicleMarker
      ? [vehicleMarker].concat(chargingMarkers).concat([destMarker])
      : chargingMarkers.concat([destMarker]);

    this.setData({ markers: markers });
  },

  saveRecentTrip: function(dest) {
    var that = this;
    var trips = wx.getStorageSync("recent_trips") || [];

    // Remove duplicate
    trips = trips.filter(function(t) {
      return t.destinationName !== dest.name;
    });

    // Add new trip at beginning
    trips.unshift({
      id: Date.now(),
      destinationName: dest.name,
      destinationAddress: dest.address,
      latitude: dest.latitude,
      longitude: dest.longitude,
      distanceKm: that.data.routeData ? that.data.routeData.total_distance : 0,
      timestamp: Date.now()
    });

    // Keep only 10 recent trips
    trips = trips.slice(0, 10);

    wx.setStorageSync("recent_trips", trips);
    this.setData({ recentTrips: trips });
  },

  cancelRoute: function() {
    this.setData({
      pageState: "idle",
      panelState: "half",
      destination: null,
      routeData: null,
      polylines: []
    });
    this.loadNearbyStations();
  },

  startNavigation: function() {
    var dest = this.data.destination;
    if (!dest) return;

    wx.openLocation({
      latitude: dest.latitude,
      longitude: dest.longitude,
      name: dest.name,
      address: dest.address || ""
    });
  },

  sendToVehicle: function() {
    var that = this;
    if (!this.data.hasVehicle || !this.data.vehicle) {
      wx.showToast({ title: "请先连接车辆", icon: "none" });
      return;
    }

    var dest = this.data.destination;
    if (!dest) return;

    wx.showLoading({ title: "发送中..." });

    api.sendNavigation(this.data.vehicle.id, {
      latitude: dest.latitude,
      longitude: dest.longitude,
      name: dest.name
    }).then(function() {
      wx.hideLoading();
      wx.showToast({ title: "已发送到车辆", icon: "success" });
    }).catch(function(err) {
      wx.hideLoading();
      console.error("Failed to send navigation:", err);
      wx.showToast({ title: "发送失败", icon: "none" });
    });
  },

  editRoute: function() {
    wx.navigateTo({
      url: "/pages/route-edit/route-edit?routeData=" + encodeURIComponent(JSON.stringify(this.data.routeData))
    });
  },

  editDepartureSOC: function() {
    var that = this;
    wx.showActionSheet({
      itemList: ["50%", "60%", "70%", "80%", "90%", "100%"],
      success: function(res) {
        var socValues = [50, 60, 70, 80, 90, 100];
        that.setData({ departureSOC: socValues[res.tapIndex] });
        if (that.data.destination) {
          that.planRoute();
        }
      }
    });
  },

  onMarkerTap: function(e) {
    var markerId = e.markerId;
    var marker = this.data.markers.find(function(m) { return m.id === markerId; });
    if (marker && marker.stationData) {
      this.navigateToStation(marker.stationData);
    }
  },

  onRegionChange: function(e) {
    // Could update nearby stations based on new region
  },

  onMapTap: function() {
    if (this.data.panelState === "expanded") {
      this.setData({ panelState: "half" });
    }
  },

  onConnectionTap: function() {
    if (this.data.hasVehicle) {
      wx.navigateTo({ url: "/pages/vehicle/vehicle" });
    }
  },

  onNavigationTap: function() {
    // Open navigation/route functions
    this.onSearchTap();
  },

  centerOnVehicle: function() {
    var that = this;
    if (this.data.vehicleState && this.data.vehicleState.latitude) {
      this.setData({
        mapCenter: {
          latitude: this.data.vehicleState.latitude,
          longitude: this.data.vehicleState.longitude
        }
      });
      if (this.mapCtx) {
        this.mapCtx.moveToLocation({
          latitude: this.data.vehicleState.latitude,
          longitude: this.data.vehicleState.longitude,
          fail: function() {} // 开发者工具不支持此API
        });
      }
    } else if (this.data.vehicle) {
      // Refresh vehicle state
      this.fetchVehicleState(this.data.vehicle.id);
    }
  },

  goToBindVehicle: function() {
    var that = this;

    // First ensure user is logged in
    var token = wx.getStorageSync("token");
    if (!token) {
      // Need to login first
      wx.showLoading({ title: "登录中..." });
      app.login().then(function() {
        wx.hideLoading();
        that.navigateToTeslaAuth();
      }).catch(function(err) {
        wx.hideLoading();
        console.error("Login failed:", err);
        wx.showToast({ title: "登录失败", icon: "none" });
      });
    } else {
      this.navigateToTeslaAuth();
    }
  },

  navigateToTeslaAuth: function() {
    // Navigate to Tesla binding page
    wx.navigateTo({ url: "/pages/vehicle-binding/vehicle-binding" });
  },

  setDestinationAndPlan: function(destination) {
    // Called from search page when destination is selected
    this.setData({
      destination: {
        name: destination.name,
        latitude: destination.latitude,
        longitude: destination.longitude,
        address: destination.address
      }
    });
    this.planRoute();
  }
});
