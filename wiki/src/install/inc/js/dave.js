(function() {
  var chromeSupported = false;
  var minVer = {
    "firefox": 38,
    "chrome": 44,
    "tor": 5
  };

  function setBrowser(browser) {
    document.documentElement.dataset.browser = browser ? "sb-" + browser : "unsupported";
  }
  function forId(id, cb) {
    var el = document.getElementById(id);
    if (el) cb(el);
  }
  var forClass = document.getElementsByClassName ? function(cn, cb) {
    var ee = document.getElementsByClassName(cn);
    for (var j = ee.length; j-- > 0;) cb(ee[j]);
  } : function () {};

  var browser,
      v =  navigator.userAgent.match(/\b(Chrome|Firefox)\/(\d+)/)
      ;
  v = v && parseInt(v[2]) || 0;
  var override = location.search.match(/\boverride=(\w+)/);
  if (override) {
    browser = override[1];
  } else if (window.InstallTrigger) {
    if (v >= minVer.firefox || minVer.firefox === 38 && new RegExp("").source) // see Fx 38 RegExp @ https://developer.mozilla.org/it/Firefox/Releases/38
      browser = "firefox";
    else {
      addEventListener("DOMContentLoaded", function() {
        forId("unsupported-other", function(el) { el.style.display = "none"; });
        if (!v) v = "< 38";
        forClass("current-firefox", function(el) { el.innerHTML = v || "< 38"; });
      }, true);
    }
  } else {
    addEventListener("DOMContentLoaded", function() { forId("unsupported-firefox", function(el) { el.style.display = "none"; }); }, true);
    if (chromeSupported &&
        /\bChrom/.test(navigator.userAgent) && /\bGoogle Inc\./.test(navigator.vendor) &&
        v >= minVer.chrome) {
          browser = "chrome";
    }
  }
  setBrowser(browser);
  var style = document.createElement("style");
  style.innerHTML = "#download-and-verify { display: none !important } #dave-init { display: block }";
  document.documentElement.firstChild.appendChild(style);

  addEventListener("load", function(ev) {
    style.innerHTML = "#dave-init { display: none }";
    forId("self-url", function (el) { el.textContent = location.href; });
    for (var browser in minVer) {
      forClass("minver-" + browser, function(el) { el.innerHTML = minVer[browser]; });
    }
  }, true);

})();
