foo({
  initialize: function (a, b) {
    this.domNode = a;
    this.slideNumberLabel = document.createElement("div");
    this.slideNumberLabel.setAttribute("class", "slideNumberLabel");
    if (b) {
      this.slideNumberLabel.innerHTML = b;
    } else {
      this.slideNumberLabel.innerHTML = "fallback";
    }
    this.slideNumberDigit = document.createElement("div");
    this.slideNumberDigit.setAttribute("class", "slideNumberDigit");
    this.domNode.appendChild(this.slideNumberLabel);
    this.domNode.appendChild(this.slideNumberDigit);
  },
  setPosition: function (b, a) {
    this.domNode.style.left = b + "px";
    this.domNode.style.top = a + "px";
  },
});
