// pages/settings/settings.js

Page({
  data: {
    settings: {
      targetArrivalSoc: 20,
      minChargingSoc: 10,
      preferSupercharger: true,
      distanceUnitIndex: 0
    },
    distanceUnits: ['Kilometers', 'Miles']
  },

  onLoad() {
    this.loadSettings();
  },

  loadSettings() {
    const savedSettings = wx.getStorageSync('settings');
    if (savedSettings) {
      this.setData({
        settings: { ...this.data.settings, ...savedSettings }
      });
    }
  },

  saveSettings() {
    wx.setStorageSync('settings', this.data.settings);
  },

  onTargetSocChange(e) {
    this.setData({
      'settings.targetArrivalSoc': e.detail.value
    });
    this.saveSettings();
  },

  onMinSocChange(e) {
    this.setData({
      'settings.minChargingSoc': e.detail.value
    });
    this.saveSettings();
  },

  onPreferSuperchargerChange(e) {
    this.setData({
      'settings.preferSupercharger': e.detail.value
    });
    this.saveSettings();
  },

  onDistanceUnitChange(e) {
    this.setData({
      'settings.distanceUnitIndex': parseInt(e.detail.value)
    });
    this.saveSettings();
  },

  showPrivacyPolicy() {
    wx.showModal({
      title: 'Privacy Policy',
      content: 'We respect your privacy. TePlanner only accesses your Tesla vehicle data for route planning purposes. We do not store your Tesla credentials or share your data with third parties.',
      showCancel: false
    });
  },

  showTerms() {
    wx.showModal({
      title: 'Terms of Service',
      content: 'By using TePlanner, you agree to use the app responsibly. Route suggestions are for reference only. Always verify charging station availability before traveling.',
      showCancel: false
    });
  }
});
