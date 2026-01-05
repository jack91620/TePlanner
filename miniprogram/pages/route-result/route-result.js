// pages/route-result/route-result.js

const app = getApp();

Page({
  data: {
    routeData: null,
    hasVehicle: false,
    sendingToCar: false,
    mapContext: null,
    markers: [],
    polyline: []
  },

  onLoad(options) {
    if (options.data) {
      try {
        const routeData = JSON.parse(decodeURIComponent(options.data));
        this.setData({
          routeData,
          hasVehicle: app.globalData.hasVehicleBound
        });

        // Prepare map data
        this.prepareMapData(routeData);
      } catch (e) {
        console.error('Failed to parse route data:', e);
        wx.showToast({
          title: 'Failed to load route',
          icon: 'none'
        });
        setTimeout(() => wx.navigateBack(), 1500);
      }
    }
  },

  onReady() {
    // Get map context
    this.mapContext = wx.createMapContext('routeMap');
  },

  prepareMapData(routeData) {
    const markers = [];
    const points = [];

    // Origin marker
    if (routeData.origin) {
      markers.push({
        id: 0,
        latitude: routeData.origin.lat,
        longitude: routeData.origin.lng,
        title: routeData.origin.name || 'Origin',
        iconPath: '/assets/icons/origin-marker.png',
        width: 32,
        height: 32
      });
      points.push({
        latitude: routeData.origin.lat,
        longitude: routeData.origin.lng
      });
    }

    // Charging stop markers
    if (routeData.charging_stops) {
      routeData.charging_stops.forEach((stop, index) => {
        markers.push({
          id: index + 1,
          latitude: stop.latitude,
          longitude: stop.longitude,
          title: stop.name,
          iconPath: '/assets/icons/charging-marker.png',
          width: 32,
          height: 32,
          callout: {
            content: `${stop.name}\nArrive: ${stop.arrival_soc}% -> ${stop.departure_soc}%`,
            display: 'BYCLICK',
            fontSize: 12,
            borderRadius: 8,
            padding: 8,
            bgColor: '#ffffff'
          }
        });
        points.push({
          latitude: stop.latitude,
          longitude: stop.longitude
        });
      });
    }

    // Destination marker
    if (routeData.destination) {
      markers.push({
        id: 999,
        latitude: routeData.destination.lat,
        longitude: routeData.destination.lng,
        title: routeData.destination.name || 'Destination',
        iconPath: '/assets/icons/destination-marker.png',
        width: 32,
        height: 32
      });
      points.push({
        latitude: routeData.destination.lat,
        longitude: routeData.destination.lng
      });
    }

    // Create polyline
    const polyline = [];
    if (points.length >= 2) {
      polyline.push({
        points: points,
        color: '#e63946',
        width: 4,
        dottedLine: false
      });
    }

    this.setData({ markers, polyline });

    // Fit map to show all points
    if (this.mapContext && points.length > 0) {
      setTimeout(() => {
        this.mapContext.includePoints({
          points: points,
          padding: [60, 60, 60, 60]
        });
      }, 500);
    }
  },

  formatDuration(minutes) {
    if (!minutes) return '0 min';
    if (minutes < 60) return `${minutes} min`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (mins === 0) return `${hours}h`;
    return `${hours}h ${mins}m`;
  },

  showStationDetail(e) {
    const station = e.currentTarget.dataset.station;
    wx.navigateTo({
      url: `/pages/station-detail/station-detail?data=${encodeURIComponent(JSON.stringify(station))}`
    });
  },

  startNavigation() {
    const { routeData } = this.data;
    if (!routeData) return;

    // Get first waypoint (either first charging station or destination)
    let firstTarget;
    if (routeData.charging_stops && routeData.charging_stops.length > 0) {
      firstTarget = {
        latitude: routeData.charging_stops[0].latitude,
        longitude: routeData.charging_stops[0].longitude,
        name: routeData.charging_stops[0].name
      };
    } else if (routeData.destination) {
      firstTarget = {
        latitude: routeData.destination.lat,
        longitude: routeData.destination.lng,
        name: routeData.destination.name
      };
    }

    if (!firstTarget) {
      wx.showToast({
        title: 'No destination',
        icon: 'none'
      });
      return;
    }

    // Open map for navigation
    wx.openLocation({
      latitude: firstTarget.latitude,
      longitude: firstTarget.longitude,
      name: firstTarget.name,
      scale: 15
    });
  },

  sendToVehicle() {
    const { routeData, hasVehicle } = this.data;
    if (!routeData) return;

    if (!hasVehicle) {
      wx.showModal({
        title: 'Not Connected',
        content: 'Please connect your Tesla first to send navigation to your vehicle.',
        confirmText: 'Connect',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({
              url: '/pages/vehicle-binding/vehicle-binding'
            });
          }
        }
      });
      return;
    }

    const token = wx.getStorageSync('token');
    if (!token) {
      wx.showToast({
        title: 'Please login first',
        icon: 'none'
      });
      return;
    }

    // Build waypoints list
    const waypoints = [];

    // Add charging stops
    if (routeData.charging_stops) {
      routeData.charging_stops.forEach(stop => {
        waypoints.push({
          latitude: stop.latitude,
          longitude: stop.longitude,
          address: stop.name
        });
      });
    }

    // Add destination
    if (routeData.destination) {
      waypoints.push({
        latitude: routeData.destination.lat,
        longitude: routeData.destination.lng,
        address: routeData.destination.name
      });
    }

    if (waypoints.length === 0) {
      wx.showToast({
        title: 'No waypoints to send',
        icon: 'none'
      });
      return;
    }

    this.setData({ sendingToCar: true });
    wx.showLoading({ title: 'Sending to vehicle...' });

    // If we have a saved route_id, use the dedicated endpoint
    if (routeData.route_id) {
      this.sendSavedRoute(token, routeData.route_id);
    } else {
      this.sendWaypoints(token, waypoints);
    }
  },

  sendSavedRoute(token, routeId) {
    wx.request({
      url: `${app.globalData.apiBaseUrl}/routes/navigate/${routeId}`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`
      },
      success: (res) => {
        wx.hideLoading();
        this.setData({ sendingToCar: false });

        if (res.statusCode === 200) {
          wx.showToast({
            title: 'Sent to vehicle!',
            icon: 'success'
          });
        } else if (res.statusCode === 503) {
          wx.showModal({
            title: 'Vehicle Offline',
            content: 'Your vehicle is offline. Would you like to wake it up?',
            confirmText: 'Wake Up',
            success: (modalRes) => {
              if (modalRes.confirm) {
                this.wakeAndSend(token, routeId);
              }
            }
          });
        } else {
          wx.showToast({
            title: res.data.detail || 'Failed to send',
            icon: 'none'
          });
        }
      },
      fail: () => {
        wx.hideLoading();
        this.setData({ sendingToCar: false });
        wx.showToast({
          title: 'Network error',
          icon: 'none'
        });
      }
    });
  },

  sendWaypoints(token, waypoints) {
    const vehicle = app.globalData.currentVehicle;
    if (!vehicle) {
      wx.hideLoading();
      this.setData({ sendingToCar: false });
      wx.showToast({
        title: 'No vehicle found',
        icon: 'none'
      });
      return;
    }

    wx.request({
      url: `${app.globalData.apiBaseUrl}/routes/navigate`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      data: {
        vehicle_id: vehicle.id,
        waypoints: waypoints
      },
      success: (res) => {
        wx.hideLoading();
        this.setData({ sendingToCar: false });

        if (res.statusCode === 200) {
          wx.showToast({
            title: `Sent ${res.data.waypoints.length} waypoints!`,
            icon: 'success'
          });
        } else if (res.statusCode === 503) {
          wx.showModal({
            title: 'Vehicle Offline',
            content: 'Your vehicle is offline. Would you like to wake it up?',
            confirmText: 'Wake Up',
            success: (modalRes) => {
              if (modalRes.confirm) {
                this.wakeVehicle(token, vehicle.id);
              }
            }
          });
        } else {
          wx.showToast({
            title: res.data.detail || 'Failed to send',
            icon: 'none'
          });
        }
      },
      fail: () => {
        wx.hideLoading();
        this.setData({ sendingToCar: false });
        wx.showToast({
          title: 'Network error',
          icon: 'none'
        });
      }
    });
  },

  wakeVehicle(token, vehicleId) {
    wx.showLoading({ title: 'Waking vehicle...' });

    wx.request({
      url: `${app.globalData.apiBaseUrl}/vehicles/${vehicleId}/wake`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`
      },
      success: (res) => {
        wx.hideLoading();
        if (res.statusCode === 200) {
          wx.showToast({
            title: 'Vehicle waking up. Try again in a moment.',
            icon: 'none',
            duration: 3000
          });
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

  wakeAndSend(token, routeId) {
    const vehicle = app.globalData.currentVehicle;
    if (!vehicle) return;

    wx.showLoading({ title: 'Waking vehicle...' });

    wx.request({
      url: `${app.globalData.apiBaseUrl}/vehicles/${vehicle.id}/wake`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`
      },
      success: (res) => {
        if (res.statusCode === 200) {
          // Wait a bit for vehicle to wake up
          setTimeout(() => {
            this.sendSavedRoute(token, routeId);
          }, 10000);
        } else {
          wx.hideLoading();
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

  shareRoute() {
    const { routeData } = this.data;
    if (!routeData) return;

    const summary = `Route: ${routeData.total_distance_km}km, ${this.formatDuration(routeData.total_duration_minutes)}`;

    wx.showActionSheet({
      itemList: ['Copy Route Summary', 'Share to Chat'],
      success: (res) => {
        if (res.tapIndex === 0) {
          // Copy to clipboard
          const text = `TePlanner Route\n` +
            `From: ${routeData.origin?.name || 'Origin'}\n` +
            `To: ${routeData.destination?.name || 'Destination'}\n` +
            `Distance: ${routeData.total_distance_km}km\n` +
            `Duration: ${this.formatDuration(routeData.total_duration_minutes)}\n` +
            `Charging Stops: ${routeData.num_charging_stops}`;

          wx.setClipboardData({
            data: text,
            success: () => {
              wx.showToast({
                title: 'Copied!',
                icon: 'success'
              });
            }
          });
        }
      }
    });
  },

  onMarkerTap(e) {
    const { markerId } = e;
    const { routeData } = this.data;

    if (markerId > 0 && markerId < 999 && routeData.charging_stops) {
      const station = routeData.charging_stops[markerId - 1];
      if (station) {
        this.showStationDetail({ currentTarget: { dataset: { station } } });
      }
    }
  },

  onShareAppMessage() {
    const { routeData } = this.data;
    return {
      title: `TePlanner: ${routeData?.total_distance_km || 0}km charging route`,
      path: '/pages/index/index'
    };
  }
});
