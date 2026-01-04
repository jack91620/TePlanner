// pages/station-detail/station-detail.js

Page({
  data: {
    station: null
  },

  onLoad(options) {
    if (options.data) {
      try {
        const station = JSON.parse(decodeURIComponent(options.data));
        this.setData({ station });
        wx.setNavigationBarTitle({
          title: station.station_name || 'Station Details'
        });
      } catch (e) {
        console.error('Failed to parse station data:', e);
        wx.navigateBack();
      }
    }
  },

  navigateToStation() {
    const { station } = this.data;
    if (!station || !station.location) return;

    wx.openLocation({
      latitude: station.location.latitude,
      longitude: station.location.longitude,
      name: station.station_name,
      address: station.location.name,
      scale: 15
    });
  }
});
