foo({
  initialize: function () {
    this.domNode = a;
    this.slideNumberLabel = document.createElement("div");
    this.slideNumberLabel.setAttribute("class", "slideNumberLabel");
    // removed conditional for reduction testing
    this.slideNumberDigit = document.createElement("div");
    this.slideNumberDigit.setAttribute("class", "slideNumberDigit");
    this.domNode.appendChild(this.slideNumberLabel);
    this.domNode.appendChild(this.slideNumberDigit);
    this.isShowing = false;
  },
  setPosition: function () {
    this.domNode.style.left = b + "px";
    this.domNode.style.top = a + "px";
  },
  setSlideNumber: function (a) {
    this.slideNumberDigit.innerHTML = a;
  },
});
