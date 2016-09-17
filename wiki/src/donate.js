$(document).ready(function(){

  // Append anchor at the end of return and cancel_return page.
  // This will allow calculating conversion rates and failures from different sources.
  $('#paypal-with-js .return-url').each(function() {
    $(this).attr("value", $(this).attr("value").concat(window.location.hash));
  });

  // Show version with JavaScript
  $('#paypal-with-js').show();
  $('#paypal-without-js').hide();

  // Toggle between Zwiebelfreunde and Riseup Labs
  $('.donate-dollars').show();
  $('.donate-euros').hide();
  $('#currency-dollar').click(function () {
    $('#dollar-amounts').show();
    $('#dollar-tax').show();
    $('#euro-amounts').hide();
    $('#euro-tax').hide();
    document.getElementById('business').value = 'tailsriseuplabs@riseup.net';
    document.getElementById('currency_code').value = 'USD';
  })
  $('#currency-euro').click(function () {
    $('.donate-dollars').hide();
    $('.donate-euros').show();
    document.getElementById('business').value = 'tails@torservers.net';
    document.getElementById('currency_code').value = 'EUR';
  })

  // Toggle between one-time donation and recurring donation
  $('#one-time').click(function () {
    document.getElementById('cmd').value = '_donations';
    document.getElementById('t3').value = '';
  })
  $('#monthly').click(function () {
    document.getElementById('cmd').value = '_xclick-subscriptions';
    document.getElementById('t3').value = 'M';
  })
  $('#yearly').click(function () {
    document.getElementById('cmd').value = '_xclick-subscriptions';
    document.getElementById('t3').value = 'Y';
  })

  // Update amount
  $('.5').click(function () {
    document.getElementById('amount').value = '5';
    document.getElementById('a3').value = '5';
  })
  $('.10').click(function () {
    document.getElementById('amount').value = '10';
    document.getElementById('a3').value = '10';
  })
  $('.20').click(function () {
    document.getElementById('amount').value = '20';
    document.getElementById('a3').value = '20';
  })
  $('.50').click(function () {
    document.getElementById('amount').value = '50';
    document.getElementById('a3').value = '50';
  })
  $('.100').click(function () {
    document.getElementById('amount').value = '100';
    document.getElementById('a3').value = '100';
  })
  $('.250').click(function () {
    document.getElementById('amount').value = '250';
    document.getElementById('a3').value = '500';
  })
  $('.500').click(function () {
    document.getElementById('amount').value = '500';
    document.getElementById('a3').value = '500';
  })
  $('#other-dollar').change(function () {
    document.getElementById('amount').value = document.getElementById('other-dollar').value;
    document.getElementById('a3').value = document.getElementById('other-dollar').value;
  })
  $('#other-euro').change(function () {
    document.getElementById('amount').value = document.getElementById('other-euro').value;
    document.getElementById('a3').value = document.getElementById('other-euro').value;
  })

});
