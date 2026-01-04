/**
 * TePlanner - Tesla Intelligent Charging Route Planner
 * WeChat Mini Program Entry
 */

App({
  globalData: {
    userInfo: null,
    hasVehicleBound: false,
    currentVehicle: null,
    apiBaseUrl: 'https://api.teplanner.com/api/v1', // Replace with actual API URL
  },

  onLaunch() {
    // Check login status
    this.checkLoginStatus();
  },

  checkLoginStatus() {
    const token = wx.getStorageSync('token');
    if (token) {
      // Validate token with backend
      this.validateToken(token);
    }
  },

  validateToken(token) {
    wx.request({
      url: `${this.globalData.apiBaseUrl}/auth/validate`,
      method: 'GET',
      header: {
        'Authorization': `Bearer ${token}`
      },
      success: (res) => {
        if (res.statusCode === 200) {
          this.globalData.userInfo = res.data.user;
          this.globalData.hasVehicleBound = res.data.hasVehicleBound;
        } else {
          // Token invalid, clear storage
          wx.removeStorageSync('token');
        }
      },
      fail: () => {
        // Network error, keep token for retry
      }
    });
  },

  // WeChat login
  login() {
    return new Promise((resolve, reject) => {
      wx.login({
        success: (res) => {
          if (res.code) {
            // Send code to backend for token exchange
            wx.request({
              url: `${this.globalData.apiBaseUrl}/auth/wechat/login`,
              method: 'POST',
              data: { code: res.code },
              success: (response) => {
                if (response.statusCode === 200) {
                  const { token, user } = response.data;
                  wx.setStorageSync('token', token);
                  this.globalData.userInfo = user;
                  resolve(user);
                } else {
                  reject(new Error('Login failed'));
                }
              },
              fail: reject
            });
          } else {
            reject(new Error('wx.login failed'));
          }
        },
        fail: reject
      });
    });
  }
});
