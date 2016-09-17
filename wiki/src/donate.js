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
    $('.donate-dollars').show();
    $('.donate-euros').hide();
    document.getElementById('business').value = 'tailsriseuplabs@riseup.net';
    document.getElementById('currency_code').value = 'USD';
  });
  $('#currency-euro').click(function () {
    $('.donate-dollars').hide();
    $('.donate-euros').show();
    document.getElementById('business').value = 'tails@torservers.net';
    document.getElementById('currency_code').value = 'EUR';
  });

  // Toggle between one-time donation and recurring donation
  $('#one-time').click(function () {
    document.getElementById('cmd').value = '_donations';
    document.getElementById('t3').value = '';
  });
  $('#monthly').click(function () {
    document.getElementById('cmd').value = '_xclick-subscriptions';
    document.getElementById('t3').value = 'M';
  });
  $('#yearly').click(function () {
    document.getElementById('cmd').value = '_xclick-subscriptions';
    document.getElementById('t3').value = 'Y';
  });

  $('.amounts .btn').on('click donate', function () {
    let newvalue = parseInt($(this).find('input').val());
    if(newvalue === undefined || newvalue < 0) { newvalue = 1; }
    $('#amount, #a3').val(newvalue);
  });

});
