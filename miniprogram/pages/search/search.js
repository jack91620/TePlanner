var app = getApp();
var api = require("../../utils/api");

Page({
  data: {
    keyword: "",
    results: [],
    recentSearches: [],
    loading: false,
    searched: false
  },

  onLoad: function() {
    this.loadRecentSearches();
  },

  loadRecentSearches: function() {
    var recent = wx.getStorageSync("recent_searches") || [];
    this.setData({ recentSearches: recent });
  },

  onInput: function(e) {
    var keyword = e.detail.value;
    this.setData({ keyword: keyword });

    // Auto search with debounce
    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }

    if (keyword.trim()) {
      this.searchTimer = setTimeout(function() {
        this.doSearch(keyword);
      }.bind(this), 500);
    } else {
      this.setData({ results: [], searched: false });
    }
  },

  onSearch: function() {
    var keyword = this.data.keyword.trim();
    if (keyword) {
      this.doSearch(keyword);
    }
  },

  doSearch: function(keyword) {
    var that = this;
    that.setData({ loading: true, searched: true });

    // Use geocode API to search for places
    api.geocode(keyword).then(function(result) {
      that.setData({ loading: false });

      if (result && result.location) {
        // Single result from geocode
        that.setData({
          results: [{
            id: "geo_1",
            title: result.title || keyword,
            name: result.title || keyword,
            address: result.address || keyword,
            latitude: result.location.lat,
            longitude: result.location.lng
          }]
        });
        that.saveRecentSearch(keyword);
      } else {
        that.setData({ results: [] });
      }
    }).catch(function(err) {
      console.error("Search failed:", err);
      that.setData({ loading: false, results: [] });

      // Fallback: use wx.chooseLocation if geocode fails
      wx.showModal({
        title: "搜索失败",
        content: "是否打开地图选择位置？",
        confirmText: "打开地图",
        success: function(res) {
          if (res.confirm) {
            that.openMapPicker();
          }
        }
      });
    });
  },

  openMapPicker: function() {
    var that = this;
    wx.chooseLocation({
      success: function(res) {
        if (res.name) {
          that.selectDestination({
            name: res.name,
            address: res.address,
            latitude: res.latitude,
            longitude: res.longitude
          });
        }
      }
    });
  },

  clearInput: function() {
    this.setData({ keyword: "", results: [], searched: false });
  },

  onResultTap: function(e) {
    var item = e.currentTarget.dataset.item;
    this.selectDestination({
      name: item.title || item.name,
      address: item.address,
      latitude: item.latitude,
      longitude: item.longitude
    });
  },

  onRecentTap: function(e) {
    var keyword = e.currentTarget.dataset.keyword;
    this.setData({ keyword: keyword });
    this.doSearch(keyword);
  },

  selectDestination: function(destination) {
    // Save to recent searches
    this.saveRecentSearch(destination.name);

    // Get previous page and set destination
    var pages = getCurrentPages();
    if (pages.length >= 2) {
      var prevPage = pages[pages.length - 2];
      if (prevPage.setDestinationAndPlan) {
        prevPage.setDestinationAndPlan(destination);
      } else {
        // Fallback: store in global data
        app.globalData.selectedDestination = destination;
      }
    }

    wx.navigateBack();
  },

  saveRecentSearch: function(keyword) {
    var recent = wx.getStorageSync("recent_searches") || [];
    // Remove duplicate
    recent = recent.filter(function(item) {
      return item !== keyword;
    });
    // Add to front
    recent.unshift(keyword);
    // Keep only 10
    recent = recent.slice(0, 10);
    wx.setStorageSync("recent_searches", recent);
    this.setData({ recentSearches: recent });
  },

  clearRecent: function() {
    wx.removeStorageSync("recent_searches");
    this.setData({ recentSearches: [] });
  }
});
