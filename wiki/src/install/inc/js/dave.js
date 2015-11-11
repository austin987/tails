(function() {
  var chromeSupported = !/\bchrome-unsupported\b/.test(document.documentElement.className);
  var minVer = {
    "firefox": 38,
    "chrome": 44,
    "tor": 5
  };

  function setBrowser(browser) {
    document.documentElement.dataset.browser = browser ? "sb-" + browser : "unsupported";
  }

  var browser,
      v =  navigator.userAgent.match(/\b(Chrome|Firefox)\/(\d+)/);
  v = v && parseInt(v[2]) || 0;
  if ("InstallTrigger" in window) {
    if (v >= minVer.firefox)
      browser = "firefox";
  } else if (chromeSupported && /\bChrom/.test(navigator.userAgent) && /\bGoogle Inc\./.test(navigator.vendor)) {
    if (v >= minVer.chrome)
      browser = "chrome";
  }
  setBrowser(browser);
  var style = document.createElement("style");
  style.innerHTML = "#download-and-verify { display: none }";
  document.documentElement.firstChild.appendChild(style);

  addEventListener("load", function(ev) {
    style.parentNode.removeChild(style);
    var ee, j;
    for (var browser in minVer) {
      ee = document.getElementsByClassName("minver-" + browser);
      for (j = ee.length; j-- > 0;)
        ee[j].innerHTML = minVer[browser];
    }
  }, true);

})();
