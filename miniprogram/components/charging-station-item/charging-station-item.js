Component({
  properties: {
    station: {
      type: Object,
      value: {}
    },
    // Display mode: 'list' (normal) | 'route' (in route planning)
    mode: {
      type: String,
      value: 'list'
    }
  },

  methods: {
    onTap() {
      this.triggerEvent('tap', { station: this.data.station });
    }
  }
});
