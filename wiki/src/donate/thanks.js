/* In the end, I couldn't get PayPal to send variables in a GET command.

// The customization of /donate/thanks can be tested using using /donate/thanks/test.

// Store the GET parameters returned by PayPal even before the page finished to launch
params = new URLSearchParams(document.location.search.substring(1));

// Hide the GET parameters returned by PayPal
window.history.replaceState(null, "donate", window.location.href.split('?')[0]);

document.addEventListener('DOMContentLoaded', function() {
  if (params.has("first_name")) {
    document.getElementById("name").innerHTML = params.get("first_name");
  }
});
*/
