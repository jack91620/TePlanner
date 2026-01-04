// pages/route-result/route-result.js

Page({
  data: {
    routeData: null
  },

  onLoad(options) {
    if (options.data) {
      try {
        const routeData = JSON.parse(decodeURIComponent(options.data));
        this.setData({ routeData });
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
      firstTarget = routeData.charging_stops[0].location;
    } else {
      firstTarget = routeData.destination;
    }

    // Open map for navigation
    wx.openLocation({
      latitude: firstTarget.latitude,
      longitude: firstTarget.longitude,
      name: firstTarget.name,
      scale: 15
    });
  }
});
