document.addEventListener('DOMContentLoaded', function() {

  document.title = "Tails";

  var date = Date.now()
  var randomMessages = document.getElementsByClassName('random-message');
  for (let i = 0; i < randomMessages.length; i++) {
    var message = randomMessages[i]
    var offset = (message.dataset.displayOffset == null) ? 0 : Number(message.dataset.displayOffset);
    if((Math.round(date / 1000 / 60 / 5) + offset) % Math.round(1 / message.dataset.displayProbability) == 0) { // divide time since epoch by slots of 5 minutes
      message.style.display = "block";
    }
  }

});
