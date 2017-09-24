document.addEventListener('DOMContentLoaded', function() {

  function opaque(elm) {
    elm.style.opacity = '1.0';
    var siblings = elm.querySelectorAll('a');
    for (let i = 0; i < siblings.length; i++) {
      siblings[i].style.pointerEvents = 'auto';
    }
  }

  function transparent(elm) {
    elm.style.opacity = '0.3';
    var siblings = elm.querySelectorAll('a');
    for (let i = 0; i < siblings.length; i++) {
      siblings[i].style.pointerEvents = 'none';
    }
  }

  function toggleOpacity(elm, mode) {
    for(var i = 0; i < elm.length; i++) {
      if(mode == 'opaque') {
        opaque(elm[i]);
      } else {
        transparent(elm[i]);
      }
    }
  }

  function hide(elm) {
    elm.style.display = 'none';
  }

  function show(elm) {
    elm.style.display = 'initial';
    if(elm.classList.contains('block')) {
      elm.style.display = 'block';
    }
    if(elm.classList.contains('inline-block')) {
      elm.style.display = 'inline-block';
    }
  }

  function toggleDisplay(elm, mode) {
    for(var i = 0; i < elm.length; i++) {
      if(mode == 'hide') {
        hide(elm[i]);
      } else {
        show(elm[i]);
      }
    }
  }

  function detectBrowser() {
    // XXX: This should be set by the browser detection script
    var vendor = 'firefox';
    if(vendor == 'firefox') {
      showVersionForSupportedBrowser();
      toggleDisplay(document.getElementsByClassName('chrome'), 'hide');
      toggleDisplay(document.getElementsByClassName('firefox'), 'show');
    }
    if(vendor == 'chrome') {
      showVersionForSupportedBrowser();
      toggleDisplay(document.getElementsByClassName('firefox'), 'hide');
      toggleDisplay(document.getElementsByClassName('chrome'), 'show');
    }
  }

  function showVersionForSupportedBrowser() {
    toggleDisplay(document.getElementsByClassName('no-js'), 'hide');
    toggleDisplay(document.getElementsByClassName('supported-browser'), 'show');
    transparent(document.getElementById('step-verify-direct'), 'transparent');
    transparent(document.getElementById('step-continue-direct'), 'transparent');
    transparent(document.getElementById('step-verify-bittorrent'), 'transparent');
  }

  function toggleNextStep(state) {
    hide(document.getElementById('skip-download-direct'));
    hide(document.getElementById('skip-verification-direct'));
    hide(document.getElementById('next-direct'));
    show(document.getElementById(state));
  }

  function showUpdateExtension() {
    hide(document.getElementById('install-extension'));
    hide(document.getElementById('extension-installed'));
    show(document.getElementById('update-extension'));
    show(document.getElementById('extension-updated'));
  }

  function resetVerificationResult(result) {
    hide(document.getElementById('verifying-download'));
    hide(document.getElementById('verification-successful'));
    hide(document.getElementById('verification-failed'));
    hide(document.getElementById('verification-failed-again'));
    toggleNextStep('skip-verification-direct');
  }

  function showVerifyingDownload() {
    hide(document.getElementById('verify-download'));
    show(document.getElementById('verifying-download'));
  }

  function showVerificationResult(result) {
    hide(document.getElementById('verify-download'));
    resetVerificationResult();
    if(result == 'successful') {
      show(document.getElementById('verification-successful'));
      toggleNextStep('next-direct');
    }
    if(result == 'failed') {
      show(document.getElementById('verification-failed'));
    }
    if(result == 'failed-again') {
      show(document.getElementById('verification-failed-again'));
    }
  }

  detectBrowser();

  // Display "Verify with your browser" when "Direct download" is clicked
  document.getElementById('direct-download').onclick = function() {
    opaque(document.getElementById('step-verify-direct'));
    show(document.getElementById('verify-download'));
    resetVerificationResult();
    transparent(document.getElementById('skip-download-bittorrent'));
    transparent(document.getElementById('step-continue-bittorrent'));
  }

  // Display "Update extension" instead of "Install extension"
  // XXX: This should be done by the extension instead
  showUpdateExtension();

  // Display "Verify download" when "Install extension" or "Update extension" is clicked
  // XXX: This should be done by the extension instead
  var buttons = document.getElementsByClassName('install-extension-btn');
  for (let i = 0; i < buttons.length; i++) {
    buttons[i].addEventListener('click', function() {
      hide(document.getElementById('install-extension'));
      hide(document.getElementById('update-extension'));
      show(document.getElementById('verification'));
    });
  }

  // Display "Verification successful" when "Verify download" is clicked
  // XXX: This should be done by the extension instead
  document.getElementById('verify-download').onclick = function() {
    showVerifyingDownload();
    setTimeout(function(){showVerificationResult('failed-again')}, 1500);
  }

});
