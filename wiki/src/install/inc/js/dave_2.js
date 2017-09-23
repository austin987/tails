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
      elm.style.display = 'inline-block';
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

  function toggleNextStep(state) {
    hide(document.getElementById('skip-download-direct'));
    hide(document.getElementById('skip-verification-direct'));
    hide(document.getElementById('next-direct'));
    show(document.getElementById(state));
  }

  function resetVerificationResult(result) {
    hide(document.getElementById('verification-successful'));
    hide(document.getElementById('verification-failed'));
    hide(document.getElementById('verification-failed-again'));
    toggleNextStep('skip-verification-direct');
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

  // Show initial screen for supported browser
  toggleDisplay(document.getElementsByClassName('no-js'), 'hide');
  toggleDisplay(document.getElementsByClassName('supported-browser'), 'show');
  transparent(document.getElementById('step-verify-direct'), 'transparent');
  transparent(document.getElementById('step-continue-direct'), 'transparent');
  transparent(document.getElementById('step-verify-bittorrent'), 'transparent');

  // Display "Verify with your browser" when "Direct download" is clicked
  document.getElementById('direct-download').onclick = function() {
    opaque(document.getElementById('step-verify-direct'));
    show(document.getElementById('verify-download'));
    resetVerificationResult();
    transparent(document.getElementById('skip-download-bittorrent'));
    transparent(document.getElementById('step-continue-bittorrent'));
  }

  // Display "Verify download" when "Install extension" is clicked
  // XXX: This should be done by the extension instead
  var buttons = document.getElementsByClassName('install-extension-btn');
  for (let i = 0; i < buttons.length; i++) {
    buttons[i].addEventListener('click', function() {
      hide(document.getElementById('install-extension'));
      show(document.getElementById('extension-installed'));
    });
  }

  // Display "Verification successful" when "Verify download" is clicked
  // XXX: This should be done by the extension instead
  document.getElementById('verify-download').onclick = function() {
    showVerificationResult('failed-again');
  }

});
