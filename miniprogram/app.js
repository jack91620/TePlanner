/**
 * TePlanner - Tesla Intelligent Charging Route Planner
 * WeChat Mini Program Entry
 */

App({
  globalData: {
    userInfo: null,
    hasVehicleBound: false,
    currentVehicle: null,
    apiBaseUrl: 'https://api.teplanner.cloud/api/v1', // Production API
    // apiBaseUrl: 'http://82.156.248.135:8000/api/v1', // Development API
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
              header: {
                'Content-Type': 'application/json'
              },
              data: { code: res.code },
              success: (response) => {
                if (response.statusCode === 200) {
                  const data = response.data;
                  // Store access token
                  wx.setStorageSync('token', data.access_token);
                  wx.setStorageSync('userId', data.user_id);

                  this.globalData.userInfo = {
                    id: data.user_id,
                    openid: data.openid
                  };
                  this.globalData.hasVehicleBound = data.has_tesla_linked;

                  resolve(this.globalData.userInfo);
                } else {
                  reject(new Error(response.data.detail || 'Login failed'));
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
  },

  // Get Tesla link status
  checkTeslaStatus() {
    const token = wx.getStorageSync('token');
    const userId = wx.getStorageSync('userId');

    if (!token || !userId) return Promise.resolve(false);

    return new Promise((resolve) => {
      wx.request({
        url: `${this.globalData.apiBaseUrl}/auth/tesla/status?user_id=${userId}`,
        method: 'GET',
        success: (res) => {
          if (res.statusCode === 200) {
            this.globalData.hasVehicleBound = res.data.linked && !res.data.expired;
            resolve(this.globalData.hasVehicleBound);
          } else {
            resolve(false);
          }
        },
        fail: () => resolve(false)
      });
    });
  },

  // Fetch user's vehicles
  fetchVehicles() {
    const token = wx.getStorageSync('token');
    if (!token) return Promise.resolve([]);

    return new Promise((resolve) => {
      wx.request({
        url: `${this.globalData.apiBaseUrl}/vehicles/`,
        method: 'GET',
        header: {
          'Authorization': `Bearer ${token}`
        },
        success: (res) => {
          if (res.statusCode === 200) {
            const vehicles = res.data.vehicles || [];
            if (vehicles.length > 0) {
              this.globalData.currentVehicle = vehicles[0];
              this.globalData.hasVehicleBound = true;
            }
            resolve(vehicles);
          } else {
            resolve([]);
          }
        },
        fail: () => resolve([])
      });
    });
  }
});
