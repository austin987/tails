document.addEventListener('DOMContentLoaded', function() {

  var endOfCampaign = new Date("2019-01-15");

  // Adjust the number of days remaining
  // Without JS, it's still displayed but not updated automatically and thus slightly outdated
  var numberOfDays = document.getElementsByClassName('counter-number-of-days');
  for (let i = 0; i < numberOfDays.length; i++) {
    let now = new Date();
    numberOfDays[i].textContent = Math.round((endOfCampaign-now)/24/60/60/1000);
   }

  // Display #counter-last-updated when hover on #counter-last-updated-info
  document.getElementById('counter-last-updated-info').style.display = "inline-block";
  document.getElementById('counter-last-updated-info').onmouseover = function() {
    document.getElementById('counter-last-updated').style.display = "block";
  }
  document.getElementById('counter-last-updated-info').onmouseout = function() {
    document.getElementById('counter-last-updated').style.display = "none";
  }

});
