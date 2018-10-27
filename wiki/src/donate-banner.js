document.addEventListener('DOMContentLoaded', function() {

  var endOfCampaign = new Date("2019-01-15");

  // Display days remaining when JS is enabled
  var days = document.getElementsByClassName('counter-days');
  for (let i = 0; i < days.length; i++) {
    days[i].style.display = "block";
  }

  // Adjust the number of days remaining
  var numberOfDays = document.getElementsByClassName('counter-number-of-days');
  for (let i = 0; i < numberOfDays.length; i++) {
    let now = new Date();
    numberOfDays[i].textContent = Math.round((endOfCampaign-now)/24/60/60/1000);
   }

});
