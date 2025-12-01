foo({
  initialize: function (a, b) {
    this.domNode = a;
    this.slideNumberLabel = document.createElement("div");
    this.slideNumberLabel.setAttribute("class", "slideNumberLabel");
    this.slideNumberLabel.innerHTML = b;
    this.slideNumberDigit = document.createElement("div");
    this.slideNumberDigit.setAttribute("class", "slideNumberDigit");
    this.domNode.appendChild(this.slideNumberLabel);
    this.domNode.appendChild(this.slideNumberDigit);
    this.isShowing = false;
  },
  setPosition: function (b, a) {
    this.domNode.style.left = b + "px";
    this.domNode.style.top = a + "px";
  },
  setSlideNumber: function (a) {
    this.slideNumberDigit.innerHTML = a;
  },
});
