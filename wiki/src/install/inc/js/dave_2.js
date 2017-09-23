document.addEventListener('DOMContentLoaded', function() {

  function opaque(elm) {
      elm.style.opacity = "1.0";
      var siblings = elm.querySelectorAll('a');
      for (let i = 0; i < siblings.length; i++) {
        siblings[i].classList.remove("disabled");
      }
  }

  function transparent(elm) {
      elm.style.opacity = "0.3";
      var siblings = elm.querySelectorAll('a');
      for (let i = 0; i < siblings.length; i++) {
        siblings[i].classList.add("disabled");
      }
  }

  function toggleOpacity(elm, mode) {
    for(var i = 0; i < elm.length; i++) {
      if(mode == "opaque") {
        opaque(elm[i]);
      } else {
        transparent(elm[i]);
      }
    }
  }

  function hide(elm) {
      elm.style.display = "none";
  }

  function show(elm) {
      elm.style.display = "block";
  }

  function toggleDisplay(elm, mode) {
    for(var i = 0; i < elm.length; i++) {
      if(mode == "hide") {
        hide(elm[i]);
      } else {
        show(elm[i]);
      }
    }
  }

  // Show initial screen for supported browser
  toggleDisplay(document.getElementsByClassName('no-js'), "hide");
  toggleDisplay(document.getElementsByClassName('supported-browser'), "show");
  transparent(document.getElementById('step-verify-direct'), "transparent");
  transparent(document.getElementById('step-continue-direct'), "transparent");
  transparent(document.getElementById('step-verify-bittorrent'), "transparent");

  // Display "Verify with your browser" when "Direct download is clicked"
  document.getElementById("direct-download").onclick = function() {
    opaque(document.getElementById('step-verify-direct'));
    hide(document.getElementById('skip-download-direct'));
    show(document.getElementById('skip-verification-direct'));
    transparent(document.getElementById('skip-download-bittorrent'));
    transparent(document.getElementById('step-continue-bittorrent'));
  }

});
