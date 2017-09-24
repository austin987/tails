document.addEventListener('DOMContentLoaded', function() {

  function showFloatingToggleableLinks() {
    var links = document.getElementsByClassName('floating-toggleable-link');
    for (let i = 0; i < links.length; i++) {
      links[i].style.display = 'block';
    }
  }
  showFloatingToggleableLinks();

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
    toggleDirectBitTorrent('direct');
  }

  function toggleContinueLink(method, state) {
    if(method == 'direct') {
      hide(document.getElementById('skip-download-direct'));
      hide(document.getElementById('skip-verification-direct'));
      hide(document.getElementById('next-direct'));
      show(document.getElementById(state));
    }
    if(method == 'bittorrent') {
      hide(document.getElementById('skip-download-bittorrent'));
      hide(document.getElementById('next-bittorrent'));
      show(document.getElementById(state));
    }
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
    toggleContinueLink('direct', 'skip-verification-direct');
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
      opaque(document.getElementById('step-continue-direct'));
      toggleContinueLink('direct', 'next-direct');
    }
    if(result == 'failed') {
      show(document.getElementById('verification-failed'));
    }
    if(result == 'failed-again') {
      show(document.getElementById('verification-failed-again'));
    }
  }

  function toggleDirectBitTorrent(method) {
    transparent(document.getElementById('step-verify-direct'));
    transparent(document.getElementById('step-continue-direct'));
    transparent(document.getElementById('continue-link-direct'));
    transparent(document.getElementById('step-verify-bittorrent'));
    transparent(document.getElementById('step-continue-bittorrent'));
    transparent(document.getElementById('continue-link-bittorrent'));
    if(method == 'direct') {
      opaque(document.getElementById('step-verify-direct'));
      opaque(document.getElementById('continue-link-direct'));
      show(document.getElementById('verify-download'));
    }
    if(method == 'bittorrent') {
      opaque(document.getElementById('step-verify-bittorrent'));
      opaque(document.getElementById('step-continue-bittorrent'));
      opaque(document.getElementById('continue-link-bittorrent'));
      toggleContinueLink('bittorrent', 'next-bittorrent');
    }
  }

  detectBrowser();
  toggleDirectBitTorrent('none');
  toggleContinueLink('direct', 'skip-download-direct');
  toggleContinueLink('bittorrent', 'skip-download-bittorrent');
  opaque(document.getElementById('continue-link-direct'));
  opaque(document.getElementById('continue-link-bittorrent'));

  // Display "Verify with your browser" when ISO image is clicked
  document.getElementById('download-iso').onclick = function() {
    toggleDirectBitTorrent('direct');
    resetVerificationResult();
  }

  // Display "Verify with BitTorrent" when Torrent file is clicked
  document.getElementById('download-torrent').onclick = function() {
    toggleDirectBitTorrent('bittorrent');
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
    setTimeout(function(){showVerificationResult('successful')}, 1500);
  }

});
