document.addEventListener('DOMContentLoaded', function() {

  document.title = "Tails";

  var n = 20; // Probability of displaying the survey button is 1/n

  function displaySurvey() {
    if(Math.floor(n * Math.random()) == 0) {
      document.getElementById("survey").style.display = "block";
    }
  }

  displaySurvey();

});
