document.addEventListener('DOMContentLoaded', function() {

  document.title = "Tails";

  var randomMessages = document.getElementsByClassName('random-message');
  for (let i = 0; i < randomMessages.length; i++) {
    var message = randomMessages[i]
    if(Math.floor(1/message.dataset.displayProbability * Math.random()) == 0) {
      message.style.display = "block";
      if(message.id == "donate") {
        document.documentElement.dataset.hideSidebarDonate = "true";
      }
    }
  }

});
