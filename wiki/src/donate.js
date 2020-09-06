document.addEventListener('DOMContentLoaded', function() {

  // A/B testing
  let variant;
  if (false) { // Math.round(Date.now() / 1000 / 60 / 60 / 5) % 2 == 0) { // divide time since epoch by slots of 5 hours
    variant = "default";
    document.getElementById("variant-forced").remove();
  } else {
    variant = "forced";
    document.getElementById("variant-default").remove();
  }

  function hide(elm) {
    elm.style.display = "none";
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

  function getCustom() {
    return JSON.parse(document.getElementById("custom").value);
  }

  function setCustom(custom) {
    document.getElementById("custom").value = JSON.stringify(custom);
  }
  setCustom({});

  // Show version with JavaScript
  show(document.getElementById('paypal-with-js'));
  hide(document.getElementById('paypal-without-js'));

  // Default donation is in $
  toggle(document.getElementsByClassName('donate-dollars'), "show");
  toggle(document.getElementsByClassName('donate-euros'), "hide");

  // Toggle between Zwiebelfreunde and Riseup Labs
  document.getElementById("currency-dollar").onclick = function() {
    toggle(document.getElementsByClassName('donate-dollars'), "show");
    toggle(document.getElementsByClassName('donate-euros'), "hide");
    document.getElementById('business').value = 'tailsriseuplabs@riseup.net';
    document.getElementById('currency_code').value = 'USD';
    document.getElementById('other-euro').value = "";
  }

  document.getElementById("currency-euro").onclick = function() {
    toggle(document.getElementsByClassName('donate-dollars'), "hide");
    toggle(document.getElementsByClassName('donate-euros'), "show");
    document.getElementById('business').value = 'tails@torservers.net';
    document.getElementById('currency_code').value = 'EUR';
    document.getElementById('other-dollar').value = "";
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

  // Toggle button groups
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

  // Change donation values on change and on click
  var defaultvalue = 5;
  var belement = document.getElementsByClassName('btn-amount');
  for (let i = 0; i < belement.length; i++) {
    belement[i].addEventListener('click', function() {
      let newvalue = parseInt(belement[i].querySelector('input').value);
      if(newvalue === undefined || newvalue < 0) { newvalue = defaultvalue; }
      document.getElementById('a3').value = newvalue;
      document.getElementById('amount').value = newvalue;
      document.getElementById('other-euro').value = "";
      document.getElementById('other-dollar').value = "";
    });

    belement[i].addEventListener('change', function() {
      let newvalue = parseInt(belement[i].querySelector('input').value);
      if(newvalue === undefined || newvalue < 0) { newvalue = defaultvalue; }
      document.getElementById('a3').value = newvalue;
      document.getElementById('amount').value = newvalue;
    });
  }

  // Pass-through the ?r= parameter to /donate/thanks and /donate/canceled
  var url = new URL(window.location.href);
  var r = url.searchParams.get("r");
  if (r) {
    var returnUrls = document.getElementsByClassName('return-url');
    for (let i = 0; i < returnUrls.length; i++) {
      let element = returnUrls[i];
      let url = new URL(element.value);
      element.value = url.origin + url.pathname + "?r=" + r;
    }
  }

  // Alternate between our different bitcoin addresses
  var bitcoinAddresses = document.getElementsByClassName('bitcoin-address'),
  current_top_weight = 0,
  picked_value,
  ranges_end = [];

  for (let i = 0; i < bitcoinAddresses.length; i++) {
    hide(bitcoinAddresses[i]);
    ranges_end[i]
    = current_top_weight
    = current_top_weight + parseInt(bitcoinAddresses[i].dataset.weight);
  }

  picked_value = Math.floor(Math.random() * current_top_weight);

  for (let i = 0; i <= bitcoinAddresses.length; i++) {
    if (picked_value < ranges_end[i]) {
      show(bitcoinAddresses[i]);
      break;
    }
  }

  if (variant == "forced") {
    // Make sure that a frequency is selected
    var frequency = false;
    document.getElementById("donate-paypal-button").onclick = function(e) {
      frequencies = document.getElementsByName("frequency");
      for (let i = 0; i < frequencies.length; i++) {
        if (frequencies[i].checked) frequency = frequencies[i].id;
      }
      if (!frequency) {
        e.preventDefault();
        document.getElementById("donate-paypal-button").classList.remove("active");
        document.getElementById("frequency-buttons").classList.add("shake");
      }
    }
  }

  // Newsletter subscription
  function newsletterSubscription() {
    var custom = getCustom();
    if (document.getElementById("opt-in").checked) {
      custom.newsletter = true;
      show(document.getElementById("email"));
    } else {
      custom.newsletter = false;
      hide(document.getElementById("email"));
    }
    setCustom(custom);
  }
  newsletterSubscription();
  document.getElementById("opt-in").onclick = function(e) {
    newsletterSubscription();
  }

});
