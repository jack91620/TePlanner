// pages/profile/profile.js

const app = getApp();

Page({
  data: {
    userInfo: null,
    hasVehicle: false,
    vehicle: null,
    refreshing: false
  },

  onLoad() {
    this.loadUserInfo();
  },

  onShow() {
    // Refresh when page shows
    this.loadUserInfo();
  },

  loadUserInfo() {
    const userInfo = app.globalData.userInfo;
    const hasVehicle = app.globalData.hasVehicleBound;
    const vehicle = app.globalData.currentVehicle;

    this.setData({
      userInfo,
      hasVehicle,
      vehicle
    });

    if (hasVehicle) {
      this.refreshVehicle();
    }
  },

  refreshVehicle() {
    const token = wx.getStorageSync('token');
    if (!token) return;

    this.setData({ refreshing: true });

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
          this.setData({ vehicle });
        }
      },
      complete: () => {
        this.setData({ refreshing: false });
      }
    });
  },

  goToBindVehicle() {
    wx.navigateTo({
      url: '/pages/vehicle-binding/vehicle-binding'
    });
  },

  goToSettings() {
    wx.navigateTo({
      url: '/pages/settings/settings'
    });
  },

  viewTripHistory() {
    // TODO: Navigate to trip history page
    wx.showToast({
      title: 'Coming soon',
      icon: 'none'
    });
  },

  unbindVehicle() {
    wx.showModal({
      title: 'Disconnect Tesla',
      content: 'Are you sure you want to disconnect your Tesla account?',
      confirmText: 'Disconnect',
      confirmColor: '#e74c3c',
      success: (res) => {
        if (res.confirm) {
          this.doUnbind();
        }
      }
    });
  },

  doUnbind() {
    const token = wx.getStorageSync('token');

    wx.showLoading({ title: 'Disconnecting...' });

    wx.request({
      url: `${app.globalData.apiBaseUrl}/auth/tesla/unbind`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`
      },
      success: (res) => {
        wx.hideLoading();

        if (res.statusCode === 200) {
          app.globalData.hasVehicleBound = false;
          app.globalData.currentVehicle = null;

          this.setData({
            hasVehicle: false,
            vehicle: null
          });

          wx.showToast({
            title: 'Disconnected',
            icon: 'success'
          });
        } else {
          wx.showToast({
            title: 'Failed to disconnect',
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
  }
});
