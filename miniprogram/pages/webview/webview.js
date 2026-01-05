// pages/webview/webview.js

const app = getApp();

Page({
  data: {
    url: '',
    type: '', // 'tesla_oauth' or other types
    loading: true,
    error: false,
    errorMessage: ''
  },

  onLoad(options) {
    const { url, type } = options;

    if (!url) {
      this.setData({
        loading: false,
        error: true,
        errorMessage: 'No URL provided'
      });
      return;
    }

    // Decode the URL
    const decodedUrl = decodeURIComponent(url);

    this.setData({
      url: decodedUrl,
      type: type || 'default',
      loading: true
    });

    console.log('WebView loading URL:', decodedUrl);
  },

  onMessage(e) {
    // Handle messages from the web page
    const data = e.detail.data;
    console.log('WebView message received:', data);

    if (data && data.length > 0) {
      const message = data[data.length - 1];

      if (message.type === 'tesla_auth_success') {
        // Tesla OAuth was successful
        this.handleOAuthSuccess(message);
      } else if (message.type === 'tesla_auth_error') {
        // Tesla OAuth failed
        this.handleOAuthError(message);
      }
    }
  },

  onLoadComplete(e) {
    console.log('WebView loaded successfully');
    this.setData({ loading: false });
  },

  onError(e) {
    console.error('WebView error:', e.detail);
    this.setData({
      loading: false,
      error: true,
      errorMessage: 'Failed to load page. Please check your network connection.'
    });
  },

  handleOAuthSuccess(message) {
    wx.showToast({
      title: message.message || 'Tesla connected!',
      icon: 'success',
      duration: 2000
    });

    // Update global state
    app.globalData.hasVehicleBound = true;

    // Clear stored state
    wx.removeStorageSync('tesla_oauth_state');

    // Navigate back after delay
    setTimeout(() => {
      wx.navigateBack({ delta: 2 }); // Go back 2 pages (past vehicle-binding)
    }, 1500);
  },

  handleOAuthError(message) {
    wx.showToast({
      title: message.message || 'Authorization failed',
      icon: 'none',
      duration: 3000
    });

    // Clear stored state
    wx.removeStorageSync('tesla_oauth_state');

    setTimeout(() => {
      wx.navigateBack();
    }, 2000);
  },

  retry() {
    if (this.data.url) {
      this.setData({
        error: false,
        loading: true
      });
      // Force reload by appending a timestamp
      const separator = this.data.url.includes('?') ? '&' : '?';
      const newUrl = `${this.data.url}${separator}_t=${Date.now()}`;
      this.setData({ url: newUrl });
    }
  },

  goBack() {
    wx.navigateBack();
  },

  onUnload() {
    // Page is being closed
    console.log('WebView page unloaded');
  },

  onShareAppMessage() {
    return {
      title: 'TePlanner - Tesla Authorization',
      path: '/pages/index/index'
    };
  }
});
