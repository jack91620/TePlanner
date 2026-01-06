// pages/vehicle-binding/vehicle-binding.js

var app = getApp();
var api = require('../../utils/api');

Page({
  data: {
    loading: false,
    step: 'intro',  // 'intro' | 'waiting' | 'success' | 'error'
    oauthUrl: '',
    errorMessage: ''
  },

  onLoad: function() {
    // Check if already bound
    this.checkExistingBinding();
  },

  onShow: function() {
    // When user returns from browser, check if binding succeeded
    if (this.data.step === 'waiting') {
      this.checkBindingStatus();
    }
  },

  checkExistingBinding: function() {
    var userId = wx.getStorageSync('userId');
    if (!userId) return;

    api.checkTeslaStatus().then(function(status) {
      if (status.linked && !status.expired) {
        app.globalData.hasVehicleBound = true;
        wx.showToast({ title: '已连接', icon: 'success' });
        setTimeout(function() {
          wx.navigateBack();
        }, 1500);
      }
    }).catch(function() {});
  },

  startBinding: function() {
    var that = this;
    this.setData({ loading: true });

    // First ensure user is logged in
    var token = wx.getStorageSync('token');
    if (!token) {
      this.loginThenBind();
      return;
    }

    this.initiateOAuth();
  },

  loginThenBind: function() {
    var that = this;
    app.login().then(function() {
      that.initiateOAuth();
    }).catch(function(e) {
      that.setData({ loading: false });
      wx.showToast({ title: '登录失败', icon: 'none' });
    });
  },

  initiateOAuth: function() {
    var that = this;
    var userId = wx.getStorageSync('userId');

    // Get Tesla OAuth URL from backend
    wx.request({
      url: app.globalData.apiBaseUrl + '/auth/tesla/authorize?user_id=' + userId,
      method: 'GET',
      success: function(res) {
        that.setData({ loading: false });

        if (res.statusCode === 200) {
          var url = res.data.url;
          var state = res.data.state;

          // Store state for verification
          wx.setStorageSync('tesla_oauth_state', state);

          that.setData({
            oauthUrl: url,
            step: 'waiting'
          });

          // Copy URL to clipboard
          wx.setClipboardData({
            data: url,
            success: function() {
              wx.showModal({
                title: '授权链接已复制',
                content: '请在手机浏览器中粘贴链接并打开，完成 Tesla 账户授权后返回此页面。',
                showCancel: false,
                confirmText: '我知道了'
              });
            }
          });
        } else {
          that.setData({
            step: 'error',
            errorMessage: res.data.detail || '获取授权链接失败'
          });
        }
      },
      fail: function() {
        that.setData({
          loading: false,
          step: 'error',
          errorMessage: '网络错误，请重试'
        });
      }
    });
  },

  copyUrl: function() {
    var that = this;
    if (!this.data.oauthUrl) return;

    wx.setClipboardData({
      data: this.data.oauthUrl,
      success: function() {
        wx.showToast({ title: '已复制', icon: 'success' });
      }
    });
  },

  checkBindingStatus: function() {
    var that = this;
    var userId = wx.getStorageSync('userId');
    if (!userId) return;

    wx.showLoading({ title: '检查授权状态...' });

    api.checkTeslaStatus().then(function(status) {
      wx.hideLoading();

      if (status.linked && !status.expired) {
        that.setData({ step: 'success' });
        app.globalData.hasVehicleBound = true;

        wx.showToast({ title: '连接成功', icon: 'success' });

        setTimeout(function() {
          wx.navigateBack();
        }, 1500);
      } else {
        // Still not bound, user can try again
        wx.showModal({
          title: '未检测到授权',
          content: '请确认已在浏览器中完成 Tesla 账户授权。如果已完成，请稍等片刻后点击"检查状态"。',
          showCancel: true,
          cancelText: '重新授权',
          confirmText: '再次检查',
          success: function(res) {
            if (res.confirm) {
              that.checkBindingStatus();
            } else {
              that.setData({ step: 'intro' });
            }
          }
        });
      }
    }).catch(function(err) {
      wx.hideLoading();
      wx.showToast({ title: '检查失败', icon: 'none' });
    });
  },

  retry: function() {
    this.setData({
      step: 'intro',
      errorMessage: '',
      oauthUrl: ''
    });
  },

  skipBinding: function() {
    wx.navigateBack();
  }
});
