Component({
  properties: {
    // Panel state: 'collapsed' | 'half' | 'expanded'
    panelState: {
      type: String,
      value: 'half'
    },
    // Heights in px
    collapsedHeight: {
      type: Number,
      value: 140
    },
    halfHeight: {
      type: Number,
      value: 400
    },
    expandedHeight: {
      type: Number,
      value: 700
    }
  },

  data: {
    currentHeight: 400,
    startY: 0,
    startHeight: 0,
    isDragging: false,
    velocity: 0,
    lastMoveTime: 0,
    lastMoveY: 0,
    scrollTop: 0
  },

  lifetimes: {
    attached() {
      this.updateHeightFromState();
    }
  },

  observers: {
    'panelState': function(state) {
      this.updateHeightFromState();
    }
  },

  methods: {
    updateHeightFromState() {
      const { panelState, collapsedHeight, halfHeight, expandedHeight } = this.data;
      let height;
      switch (panelState) {
        case 'collapsed':
          height = collapsedHeight;
          break;
        case 'expanded':
          height = expandedHeight;
          break;
        default:
          height = halfHeight;
      }
      this.setData({ currentHeight: height });
    },

    onTouchStart(e) {
      const touch = e.touches[0];
      this.setData({
        startY: touch.clientY,
        startHeight: this.data.currentHeight,
        isDragging: true,
        lastMoveTime: Date.now(),
        lastMoveY: touch.clientY,
        velocity: 0
      });
    },

    onTouchMove(e) {
      if (!this.data.isDragging) return;

      const touch = e.touches[0];
      const deltaY = this.data.startY - touch.clientY;
      const newHeight = this.data.startHeight + deltaY;

      // Calculate velocity
      const now = Date.now();
      const dt = now - this.data.lastMoveTime;
      if (dt > 0) {
        const velocity = (this.data.lastMoveY - touch.clientY) / dt;
        this.setData({
          velocity,
          lastMoveTime: now,
          lastMoveY: touch.clientY
        });
      }

      // Clamp height with rubber band effect
      const { collapsedHeight, expandedHeight } = this.data;
      const minH = collapsedHeight - 30;
      const maxH = expandedHeight + 50;

      let clampedHeight = newHeight;
      if (newHeight < collapsedHeight) {
        // Rubber band at bottom
        const over = collapsedHeight - newHeight;
        clampedHeight = collapsedHeight - over * 0.3;
      } else if (newHeight > expandedHeight) {
        // Rubber band at top
        const over = newHeight - expandedHeight;
        clampedHeight = expandedHeight + over * 0.3;
      }

      clampedHeight = Math.max(minH, Math.min(maxH, clampedHeight));
      this.setData({ currentHeight: clampedHeight });
    },

    onTouchEnd(e) {
      const { currentHeight, velocity, collapsedHeight, halfHeight, expandedHeight } = this.data;

      this.setData({ isDragging: false });

      // Determine target state based on velocity and position
      let targetHeight;
      let targetState;

      // Fast swipe
      if (Math.abs(velocity) > 0.5) {
        if (velocity > 0) {
          // Swipe up
          if (currentHeight < halfHeight) {
            targetHeight = halfHeight;
            targetState = 'half';
          } else {
            targetHeight = expandedHeight;
            targetState = 'expanded';
          }
        } else {
          // Swipe down
          if (currentHeight > halfHeight) {
            targetHeight = halfHeight;
            targetState = 'half';
          } else {
            targetHeight = collapsedHeight;
            targetState = 'collapsed';
          }
        }
      } else {
        // Slow drag - snap to nearest
        const threshold1 = (collapsedHeight + halfHeight) / 2;
        const threshold2 = (halfHeight + expandedHeight) / 2;

        if (currentHeight < threshold1) {
          targetHeight = collapsedHeight;
          targetState = 'collapsed';
        } else if (currentHeight < threshold2) {
          targetHeight = halfHeight;
          targetState = 'half';
        } else {
          targetHeight = expandedHeight;
          targetState = 'expanded';
        }
      }

      this.setData({ currentHeight: targetHeight });
      this.triggerEvent('statechange', { state: targetState, height: targetHeight });
    },

    onScroll(e) {
      this.setData({ scrollTop: e.detail.scrollTop });
    },

    onScrollToTop() {
      // Allow panel drag when scrolled to top
    },

    // Programmatic state change
    setState(state) {
      this.setData({ panelState: state });
      this.updateHeightFromState();
      this.triggerEvent('statechange', { state, height: this.data.currentHeight });
    }
  }
});
