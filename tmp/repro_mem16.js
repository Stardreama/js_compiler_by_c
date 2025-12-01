foo({
  initialize: function () {
    if (b) {
      x();
    } else {
      y();
    }
    this.isShowing = false;
  },
  setPosition: function () {
    this.domNode.style.left = b + "px";
  },
  setSlideNumber: function (a) {
    this.slideNumberDigit.innerHTML = a;
  },
});
