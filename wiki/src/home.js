document.addEventListener('DOMContentLoaded', function() {

  document.title = "Tails";

  var randomMessages = document.getElementsByClassName('random-message');
  for (let i = 0; i < randomMessages.length; i++) {
    var message = randomMessages[i]
    if(Math.floor(message.dataset.n * Math.random()) == 0) {
      message.style.display = "block";
    }
  }

});
