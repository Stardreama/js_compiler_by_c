foo({
  init: function () {
    a();
  },
  setPosition: function () {
    this.domNode.style.left = b + "px";
    this.domNode.style.top = a + "px";
  },
  setSlideNumber: function (a) {
    this.slideNumberDigit.innerHTML = a;
  },
});
