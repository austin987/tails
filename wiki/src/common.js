// this function toggles the "hidden" class on the "togglable" element,
// if ".toggle" is clicked somewhere on the page.
// This function could be improved to toggle only the NEXT .togglable element.
document.querySelector('.toggler').addEventListener('click', function(e) {
  [].map.call(document.querySelectorAll('.togglable'), function(el) {
    // classList supports 'contains', 'add', 'remove', and 'toggle'
    el.classList.toggle('hidden');
  });
});

