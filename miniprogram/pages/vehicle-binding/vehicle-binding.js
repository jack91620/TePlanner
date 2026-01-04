// pages/vehicle-binding/vehicle-binding.js

const app = getApp();

Page({
  data: {
    loading: false
  },

  startBinding() {
    this.setData({ loading: true });

    // First ensure user is logged in
    const token = wx.getStorageSync('token');
    if (!token) {
      this.loginThenBind();
      return;
    }

    this.initiateOAuth();
  },

  async loginThenBind() {
    try {
      await app.login();
      this.initiateOAuth();
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({
        title: 'Login failed',
        icon: 'none'
      });
    }
  },

  initiateOAuth() {
    const token = wx.getStorageSync('token');

    // Get Tesla OAuth URL from backend
    wx.request({
      url: `${app.globalData.apiBaseUrl}/auth/tesla/authorize`,
      method: 'GET',
      header: {
        'Authorization': `Bearer ${token}`
      },
      success: (res) => {
        this.setData({ loading: false });

        if (res.statusCode === 200) {
          const { url, state } = res.data;

          // Store state for verification
          wx.setStorageSync('tesla_oauth_state', state);

          // Open Tesla login in web-view
          // Note: This requires a web-view page for OAuth flow
          wx.navigateTo({
            url: `/pages/webview/webview?url=${encodeURIComponent(url)}&type=tesla_oauth`
          });
        } else {
          wx.showToast({
            title: 'Failed to start binding',
            icon: 'none'
          });
        }
      },
      fail: () => {
        this.setData({ loading: false });
        wx.showToast({
          title: 'Network error',
          icon: 'none'
        });
      }
    });
  },

  skipBinding() {
    wx.navigateBack();
  },

  // Called when returning from OAuth web-view
  onOAuthCallback(code, state) {
    const savedState = wx.getStorageSync('tesla_oauth_state');

    if (state !== savedState) {
      wx.showToast({
        title: 'Invalid OAuth state',
        icon: 'none'
      });
      return;
    }

    wx.showLoading({ title: 'Connecting...' });

    const token = wx.getStorageSync('token');

    wx.request({
      url: `${app.globalData.apiBaseUrl}/auth/tesla/callback`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      data: { code, state },
      success: (res) => {
        wx.hideLoading();

        if (res.statusCode === 200) {
          app.globalData.hasVehicleBound = true;
          app.globalData.currentVehicle = res.data.vehicle;

          wx.showToast({
            title: 'Connected!',
            icon: 'success'
          });

          setTimeout(() => {
            wx.navigateBack();
          }, 1500);
        } else {
          wx.showToast({
            title: res.data.detail || 'Connection failed',
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
