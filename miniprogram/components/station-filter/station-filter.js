Component({
  properties: {
    activeFilter: {
      type: String,
      value: 'supercharger'
    },
    showDropdown: {
      type: Boolean,
      value: true
    }
  },

  data: {
    showOptions: false,
    filters: [
      { key: 'supercharger', label: '超级充电站' }
    ],
    allFilters: [
      { key: 'supercharger', label: '超级充电站', active: true },
      { key: 'destination', label: '目的地充电站', active: false },
      { key: 'other', label: '其他充电站', active: false },
      { key: 'service', label: '服务中心', active: false },
      { key: 'experience', label: '体验店', active: false },
      { key: 'bodyshop', label: '钣喷中心', active: false }
    ]
  },

  methods: {
    onFilterTap(e) {
      const key = e.currentTarget.dataset.key;
      if (this.data.showDropdown && key === 'supercharger') {
        this.setData({ showOptions: true });
      } else {
        this.triggerEvent('change', { key });
      }
    },

    onOptionTap(e) {
      const key = e.currentTarget.dataset.key;
      const allFilters = this.data.allFilters.map(f => ({
        ...f,
        active: f.key === key
      }));

      const activeFilter = allFilters.find(f => f.active);

      this.setData({
        allFilters,
        activeFilter: key,
        filters: [{ key: activeFilter.key, label: activeFilter.label }],
        showOptions: false
      });

      this.triggerEvent('change', { key });
    },

    closeOptions() {
      this.setData({ showOptions: false });
    }
  }
});
