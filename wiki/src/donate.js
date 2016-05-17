$(document).ready(function(){
  $('#dollar-amounts').show();
  $('#euro-amounts').hide();
  $('#currency-dollar').click(function () {
    $('#dollar-amounts').show();
    $('#euro-amounts').hide();
  })
  $('#currency-euro').click(function () {
    $('#dollar-amounts').hide();
    $('#euro-amounts').show();
  })
});
