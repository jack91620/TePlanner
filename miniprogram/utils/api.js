/**
 * API utility functions
 */

const app = getApp();

/**
 * Make authenticated API request
 */
function request(options) {
  return new Promise((resolve, reject) => {
    const token = wx.getStorageSync('token');

    wx.request({
      url: `${app.globalData.apiBaseUrl}${options.url}`,
      method: options.method || 'GET',
      data: options.data,
      header: {
        'Authorization': token ? `Bearer ${token}` : '',
        'Content-Type': 'application/json',
        ...options.header
      },
      success: (res) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(res.data);
        } else if (res.statusCode === 401) {
          // Token expired, clear and redirect to login
          wx.removeStorageSync('token');
          app.globalData.userInfo = null;
          reject(new Error('Unauthorized'));
        } else {
          reject(new Error(res.data.detail || 'Request failed'));
        }
      },
      fail: (err) => {
        reject(new Error(err.errMsg || 'Network error'));
      }
    });
  });
}

/**
 * GET request
 */
function get(url, params) {
  return request({
    url,
    method: 'GET',
    data: params
  });
}

/**
 * POST request
 */
function post(url, data) {
  return request({
    url,
    method: 'POST',
    data
  });
}

/**
 * PUT request
 */
function put(url, data) {
  return request({
    url,
    method: 'PUT',
    data
  });
}

/**
 * DELETE request
 */
function del(url) {
  return request({
    url,
    method: 'DELETE'
  });
}

module.exports = {
  request,
  get,
  post,
  put,
  del
};
