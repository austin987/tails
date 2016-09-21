$(document).ready(function(){

  // Append anchor at the end of return and cancel_return page.
  // This will allow calculating conversion rates and failures from different sources.
  $('#paypal-with-js .return-url').each(function() {
    $(this).val($(this).val().concat(window.location.hash));
  });

  // Show version with JavaScript
  $('#paypal-with-js').show();
  $('#paypal-without-js').hide();

  // default donation is in $
  $('.donate-dollars').show();
  $('.donate-euros').hide();

  // Toggle between Zwiebelfreunde and Riseup Labs
  $('#currency-dollar').click(function () {
    $('.donate-dollars').show();
    $('.donate-euros').hide();
    $('#dollar-amounts .btn').first().trigger('click');
    $('#business').val('tailsriseuplabs@riseup.net');
    $('#currency_code').val('USD');
  });
  $('#currency-euro').click(function () {
    $('.donate-dollars').hide();
    $('.donate-euros').show();
    $('#euro-amounts .btn').first().trigger('click');
    $('#business').val('tails@torservers.net');
    $('#currency_code').val('EUR');
  });

  // Toggle between one-time donation and recurring donation
  $('#one-time').click(function () {
    $('#cmd').val('_donations');
    $('#t3').val('');
  });
  $('#monthly').click(function () {
    $('#cmd').val('_xclick-subscriptions');
    $('#t3').val('M');
  });
  $('#yearly').click(function () {
    $('#cmd').val('_xclick-subscriptions');
    $('#t3').val('Y');
  });

  // Set the amounts for PayPal to the value of the radio button that gets clicked
  $('.amounts .btn').on('click change', function () {
    let newvalue = parseInt($(this).find('input').val());
    if(newvalue === undefined || newvalue < 0) { newvalue = 1; }
    $('#amount, #a3').val(newvalue);
  });

});
