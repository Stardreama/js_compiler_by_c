document.getElementById("downloadButtonNav").onclick = function () {
  if (gtag) {
    gtag("event", "Click", {
      event_category: "Download",
      event_label: "Nav Bar Button",
    });
  }
};
