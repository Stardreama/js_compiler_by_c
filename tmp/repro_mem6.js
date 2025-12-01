foo({
  initialize: function (a, b) {
    this.domNode = a;
    this.slideNumberLabel = document.createElement("div");
    if (b) {
      this.slideNumberLabel.innerHTML = b;
    } else {
      this.slideNumberLabel.innerHTML = "fallback";
    }
    this.slideNumberDigit = document.createElement("div");
    this.domNode.appendChild(this.slideNumberLabel);
    this.domNode.appendChild(this.slideNumberDigit);
  },
  setPosition: function (b, a) {
    this.domNode.style.left = b + "px";
    this.domNode.style.top = a + "px";
  },
});
