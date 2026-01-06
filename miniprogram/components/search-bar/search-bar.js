Component({
  properties: {
    placeholder: {
      type: String,
      value: '导航'
    },
    value: {
      type: String,
      value: ''
    },
    disabled: {
      type: Boolean,
      value: true
    },
    focus: {
      type: Boolean,
      value: false
    }
  },

  methods: {
    onTap() {
      this.triggerEvent('tap');
    },

    onInput(e) {
      this.triggerEvent('input', { value: e.detail.value });
    },

    onConfirm(e) {
      this.triggerEvent('search', { value: e.detail.value });
    }
  }
});
