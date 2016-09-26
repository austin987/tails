document.addEventListener('DOMContentLoaded', function() {

  function hide(elm) {
    elm.style.display = "hide";
  }

  function show(elm) {
      elm.style.display = "block";
  }

  function toggle(elm, mode) {
    for(var i = 0; i < elm.length; i++) {
      if(mode == "hide") {
        hide(elm[i]);
      } else {
        show(elm[i]);
      }
    }
  }

  // Show version with JavaScript
  show(document.getElementById('paypal-with-js'));
  hide(document.getElementById('paypal-without-js'));

  // default donation is in $
  toggle(document.getElementsByClassName('donate-dollars'), "show");
  toggle(document.getElementsByClassName('donate-euros'), "hide");

  // Toggle between Zwiebelfreunde and Riseup Labs
  document.getElementById("currency-dollar").onclick = function() {
    toggle(document.getElementsByClassName('donate-dollars'), "show");
    toggle(document.getElementsByClassName('donate-euros'), "hide");
    document.getElementById('business').value = 'tailsriseuplabs@riseup.net';
    document.getElementById('currency_code').value = 'USD';
  }

  document.getElementById("currency-euro").onclick = function() {
    toggle(document.getElementsByClassName('donate-dollars'), "hide");
    toggle(document.getElementsByClassName('donate-euros'), "show");
    document.getElementById('business').value = 'tails@torservers.net';
    document.getElementById('currency_code').value = 'EUR';
  }

  // Toggle between one-time donation and recurring donation
  document.getElementById("one-time").onclick = function() {
    document.getElementById('cmd').value = '_donations';
    document.getElementById('t3').value = '';
  }
  document.getElementById("monthly").onclick = function() {
    document.getElementById('cmd').value = '_xclick-subscriptions';
    document.getElementById('t3').value = 'M';
  }
  document.getElementById("yearly").onclick = function() {
    document.getElementById('cmd').value = '_xclick-subscriptions';
    document.getElementById('t3').value = 'Y';
  }

  // toggle buttons
  var element = document.getElementsByClassName('btn');
  for (let i = 0; i < element.length; i++) {
    element[i].addEventListener('click', function() {
      var siblings = element[i].parentNode.querySelectorAll('label');
      for (let j = 0; j < siblings.length; j++) {
        siblings[j].classList.remove('active');
      }
      this.classList.add('active');
    });
  }
  // fixme: add event listener change
  // change global values
  var belement = document.getElementsByClassName('btn-amount');
  for (let i = 0; i < belement.length; i++) {
    belement[i].addEventListener('click', function() {
      let newvalue = parseInt(belement[i].querySelector('input').value);
      console.log(newvalue);
      if(newvalue === undefined || newvalue < 0) { newvalue = 1; }
      document.getElementById('a3').value = newvalue;
      document.getElementById('amount').value = newvalue;
    });
  }
});
