$(function(){
  $(document).on('click', 'button', function(event) {
    var buttonName = $(event.currentTarget).data('name');
    $.get('/button/' + buttonName);
  });
});