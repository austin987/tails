document.addEventListener('DOMContentLoaded', function() {

  document.title = "Tails";

  var date = Date.now()
  var randomMessages = document.getElementsByClassName('random-message');
  for (let i = 0; i < randomMessages.length; i++) {
    var message = randomMessages[i]
    if(Math.round(date / 1000 / 60 / 5) % Math.round(1 / message.dataset.displayProbability) == 0) { // divide time since epoch by slots of 5 minutes
      message.style.display = "block";
      if(message.id == "donate") {
        document.documentElement.dataset.hideSidebarDonate = "true";
      }
    }
  }

});
