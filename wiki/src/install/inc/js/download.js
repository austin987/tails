document.addEventListener("DOMContentLoaded", function() {

  //specify url of json file containing valid checksums for ISO and USB images below:
  //var URLofJsonFileContainingChecksums='https://tails.boum.org/install/v2/Tails/amd64/stable/latest.json';  						//this URL will only work if download.html is served from  served from https://tails.boum.org/ because of same origin because of same-origin policy.
  var URLofJsonFileContainingChecksums='https://cors-anywhere.herokuapp.com/https://tails.boum.org/install/v2/Tails/amd64/stable/latest.json';  		//use this URL to get around same-origin policy (SOP) if you are staging this locally.  The https://cors-anywhere.herokuapp.com/ proxy includes the necessary CORS headers to relax SOP.

  var sha256;

  /* Generic functions */

  function hide(elm) {
    elm.style.display = "none";
  }

  function show(elm) {
    elm.style.display = "initial";
    if (elm.classList.contains("block")) {
      elm.style.display = "block";
    }
    if (elm.classList.contains("inline-block")) {
      elm.style.display = "inline-block";
    }
  }

  function toggleDisplay(elm, mode) {
    for (let i = 0; i < elm.length; i++) {
      if (mode == "hide") {
        hide(elm[i]);
      } else {
        show(elm[i]);
      }
    }
  }

  function detectBrowser() {
    /* To list the APIs that our extension is using, execute: git grep "chrome."
       Browser compatibility:

         - https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Browser_support_for_JavaScript_APIs
         - https://developer.chrome.com/extensions/api_index
    */
    minVersion = {
      "firefox": 52,  // Tor Browser when releasing Tails Verification 1.0
      "chrome": 57,   // Version from Debian Jessie, the oldest I could test
      "torbrowser": 7 // First release based on Firefox 52
    };
    document.getElementById("min-version-firefox").textContent = minVersion.firefox.toString();
    document.getElementById("min-version-chrome").textContent = minVersion.chrome.toString();
    document.getElementById("min-version-tor-browser").textContent = minVersion.torbrowser.toString();

    version = navigator.userAgent.match(/\b(Chrome|Firefox)\/(\d+)/);
    version = version && parseInt(version[2]) || 0;
    overrideVersion = location.search.match(/\bversion=(\w+)/);
    if (overrideVersion) {
      version = overrideVersion[1];
    }

    overrideBrowser = location.search.match(/\bbrowser=(\w+)/);
    if (overrideBrowser) {
      browser = overrideBrowser[1];
    } else if (window.InstallTrigger) {
      browser = "Firefox";
    } else if ((/\bChrom/).test(navigator.userAgent) && (/\bGoogle Inc\./).test(navigator.vendor)) {
      browser = "Chrome";
    }

    if (browser === "Firefox" || browser === "Chrome") {
      document.getElementById("detected-browser").textContent = browser + " " + version.toString();
    } else {
      // Don't bother displaying version number for unsupported browsers as it's probably more error prone.
      document.getElementById("detected-browser").textContent = browser;
    }

    toggleDisplay(document.getElementsByClassName("no-js"), "hide");
    if (browser === "Firefox") {
      if (version >= minVersion.firefox) {
        // Supported Firefox
        toggleDisplay(document.getElementsByClassName("supported-browser"), "show");
        toggleDisplay(document.getElementsByClassName("chrome"), "hide");
        toggleDisplay(document.getElementsByClassName("firefox"), "show");
      } else {
        // Outdated Firefox
        toggleDisplay(document.getElementsByClassName("outdated-browser"), "show");
      }
    } else if (browser === "Chrome") {
      if (version >= minVersion.chrome) {
        // Supported Chrome
        toggleDisplay(document.getElementsByClassName("supported-browser"), "show");
        toggleDisplay(document.getElementsByClassName("firefox"), "hide");
        toggleDisplay(document.getElementsByClassName("chrome"), "show");
      } else {
        // Outdated Chrome
        toggleDisplay(document.getElementsByClassName("outdated-browser"), "show");
      }
    } else {
      toggleDisplay(document.getElementsByClassName("unsupported-browser"), "show");
    }
  }

  function hitCounter(status) {
    try {
      var counter_url, url, scenario, version, cachebust;
      counter_url = "/install/download/counter";
      url = window.location.href.split("/");
      if (window.location.href.match(/\/upgrade\//)) {
        scenario = 'upgrade';
      } else {
        scenario = url[url.lastIndexOf("install") + 1];
      }
      version = document.getElementById("tails-version").textContent.replace("\n", "");
      cachebust = Math.round(new Date().getTime() / 1000);
      fetch(counter_url + "?scenario=" + scenario + "&version=" + version + "&status=" + status + "&cachebust=" + cachebust);
    } catch (e) { } // Ignore if we fail to hit the download counter
  }

  /* Display logic functions */

  function toggleJavaScriptBitTorrent(method) {
    if (method === "javascript") {
      hide(document.getElementById("bittorrent-verification-tip"));
      show(document.getElementById("javascript-verification-tip"));
    }
    else if (method === "bittorrent") {
      hide(document.getElementById("javascript-verification-tip"));
      show(document.getElementById("bittorrent-verification-tip"));
    }
  }

  function showAnotherMirror() {
    hide(document.getElementById("bittorrent"));
    show(document.getElementById("try-another-mirror"));
  }

  function showVerifyButton() {
    hide(document.getElementById("verifying-download"));
    show(document.getElementById("verify-button"));
  }

  function showVerifyingDownload(filename) {
    resetVerificationResult();
    hide(document.getElementById("verify-button"));
    if (filename) {
      var filenames = document.getElementsByClassName("verify-filename");
      for (let i = 0; i < filenames.length; i++) {
        filenames[i].textContent = filename;
      }
    }
    show(document.getElementById("verifying-download"));
    toggleContinueLink("skip-verification");
  }

  function showVerificationProgress(percentage) {
    document.getElementById("progress-bar").style.width = percentage + "%";
    document.getElementById("progress-bar").setAttribute("aria-valuenow", percentage.toString());
  }

  function showVerificationResult(result) {
    hide(document.getElementById("verify-button"));
    resetVerificationResult();
    hitCounter(result);
    if (result === "successful") {
      show(document.getElementById("verification-successful"));
      toggleContinueLink("next");
    }
    else if (result === "failed") {
      show(document.getElementById("verification-failed"));
      // Try again with different mirrors
      toggleDisplay(document.getElementsByClassName("use-mirror-pool"), "hide");
      toggleDisplay(document.getElementsByClassName("use-mirror-pool-on-retry"), "show");
      replaceUrlPrefixWithRandomMirror(document.querySelectorAll(".use-mirror-pool-on-retry"));
    }
    else if (result === "failed-again") {
      show(document.getElementById("verification-failed-again"));
    }
    else if (result === "error-json") {
      show(document.getElementById("verification-error-json"));
      document.getElementById("checksum-file").setAttribute('href', URLofJsonFileContainingChecksums);
    }
    else if (result === "error-image") {
      show(document.getElementById("verification-error-image"));
    }
  }

  function resetVerificationResult(result) {
    hide(document.getElementById("verifying-download"));
    hide(document.getElementById("verification-successful"));
    hide(document.getElementById("verification-failed"));
    hide(document.getElementById("verification-failed-again"));
    hide(document.getElementById("verification-error-json"));
    hide(document.getElementById("verification-error-image"));
    show(document.getElementById("verification"));
    toggleContinueLink("skip-verification");
  }

  function toggleContinueLink(state) {
    hide(document.getElementById("skip-download"));
    hide(document.getElementById("skip-verification"));
    hide(document.getElementById("next"));
    show(document.getElementById(state));
  }

  /* Initialize event handlers */

  // Direct download
  document.getElementById("download-img").onclick = function(e) { download(e, this); }
  document.getElementById("download-img-retry").onclick = function(e) { download(e, this); }
  document.getElementById("download-iso").onclick = function(e) { download(e, this); }
  document.getElementById("download-iso-retry").onclick = function(e) { download(e, this); }

  function download(e, elm) {
    try {
      e.preventDefault();
      hitCounter("download-image");
      toggleJavaScriptBitTorrent("javascript");
      resetVerificationResult();
      showAnotherMirror();
    } finally {
      // Setting window.location.href will abort AJAX requests resulting
      // in a NetworkError depending on the timing and browser.
      window.open(elm.getAttribute("href"), "_blank");
    }
  }

  // BitTorrent download
  document.getElementById("download-img-torrent").onclick = function(e) { downloadTorrent(e, this); }
  document.getElementById("download-iso-torrent").onclick = function(e) { downloadTorrent(e, this); }

  function downloadTorrent(e, elm) {
    try {
      e.preventDefault();
      hitCounter("download-torrent");
      toggleJavaScriptBitTorrent("bittorrent");
      toggleContinueLink("next");
    } finally {
      // Setting window.location.href will abort AJAX requests resulting
      // in a NetworkError depending on the timing and browser.
      window.open(elm.getAttribute("href"), "_blank");
    }
  }

  // Download again after failure
  document.getElementById("download-img-again").onclick = function(e) { downloadAgain(e, this); }
  document.getElementById("download-iso-again").onclick = function(e) { downloadAgain(e, this); }

  function downloadAgain(e, elm) {
    try {
      e.preventDefault();
      hitCounter("download-image-again");
      toggleJavaScriptBitTorrent("javascript");
      resetVerificationResult();
      showVerifyButton();
    } finally {
      // Setting window.location.href will abort AJAX requests resulting
      // in a NetworkError depending on the timing and browser.
      window.open(elm.getAttribute("href"), "_blank");
    }
  }

  // Trigger verification when file is chosen
  document.getElementById("verify-file").onchange = function(e) { verifyFile(e, this); }

  async function verifyFile(e, elm) {
    file = elm.files[0]

    try {
      var response=await fetch(URLofJsonFileContainingChecksums);
      var checksumjson=await response.text();
      //console.log('IDF downloaded from ' + URLofJsonFileContainingChecksums + '.');
    } catch(err) {
      showVerificationResult("error-json");
      return;
    }

    try {
      showVerifyingDownload(file.name);
      sha256=forge.md.sha256.create();
      await readFile(file);
      var fileactualchecksum = sha256.digest().toHex();
      console.log('checksum of downloaded file: ' + fileactualchecksum);
    } catch(err) {
      showVerificationResult("error-image");
      return;
    }

    //If downloaded file is valid, then fileactualchecksum should be 64 hex characters in length, and should be contained within checksumjson.  Otherwise, consider downloaded file to be invalid.
    if(fileactualchecksum.length==64 && (checksumjson.includes(fileactualchecksum.toUpperCase()) || checksumjson.includes(fileactualchecksum.toLowerCase()))) {
      showVerificationResult("successful");
    } else {
      showVerificationResult("failed");
    }
  }

  // Retry after error during verification
  document.getElementById("retry-json").onclick = function(e) { resetVerificationResult(); showVerifyButton(); }
  document.getElementById("retry-image").onclick = function(e) { resetVerificationResult(); showVerifyButton(); }

  /* Final initialization */

  // Display floating-toggleable-links to prevent people without JS to
  // either always see the toggles or have broken toggle links.
  var links = document.getElementsByClassName("floating-toggleable-link");
  for (let i = 0; i < links.length; i++) {
    show(links[i]);
  }

  detectBrowser();
  showVerifyButton();
  toggleContinueLink("skip-download");

  async function readFile(file) {
    var CHUNK_SIZE = 2 * 1024 *1024;
    var offset = 0;
    lastCalculatedPercentage=0;
    while(true) {
      var chunk = await readChunk(file, offset, CHUNK_SIZE);
      sha256.update(chunk);
      offset+=chunk.length;

      var progressPercent = parseInt(offset * 100.0 / file.size);
      if (progressPercent!=lastCalculatedPercentage) {
        lastCalculatedPercentage = progressPercent;
        showVerificationProgress(progressPercent);
      }

      if (chunk.length < CHUNK_SIZE) { return; }
    }
  }

  function readChunk(file, chunk_offset, chunk_size) {
    return new Promise(function(resolve, reject) {
      let fr = new FileReader();
      fr.onload = e => {
        resolve(e.target.result);
      };

      // on error, reject the promise
      fr.onerror = (e) => {
        reject(e);
      };
      let slice = file.slice(chunk_offset, chunk_offset + chunk_size);

      // This API is non-standard: https://developer.mozilla.org/en-US/docs/Web/API/FileReader/readAsBinaryString
      // We use it for performance reasons, see #15059.
      fr.readAsBinaryString(slice);
    });
  }

  // To debug the display of the different states:
  // showVerifyingDownload('test.img');
  // showVerificationProgress('50');
  // showVerificationResult("successful");
  // showVerificationResult("failed");
  // showVerificationResult("failed-again");
  // showVerificationResult("error-json");
  // showVerificationResult("error-image");

});
