foo({
  initialize: function (a, b) {
    this.domNode = a;
    this.slideNumberLabel = document.createElement("div");
    this.slideNumberLabel.setAttribute("class", "slideNumberLabel");
    if (b) {
      this.slideNumberLabel.innerHTML = b;
    } else {
      this.slideNumberLabel.innerHTML = "Press Return to go to slide:";
    }
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
  show: function () {
    this.isShowing = true;
    this.domNode.style.display = "block";
    this.domNode.style.opacity = 1;
  },
});
