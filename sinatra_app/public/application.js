$(function(){
  $(document).on('click', 'button', function(event) {
    var buttonName = $(event.currentTarget).data('name');
    $.get('/button/' + buttonName);
  });

  var updateInfo = function(){
    $.get('/info.json', function(data) {
      var info = data.info, barcodes = data.barcodes;

      if (info.error) {
        $('.screen .info').hide();
        $('.screen .error').show();
      } else {
        $('.screen.error').hide();
        $('.screen .on').html(info.on ? 'On' : 'Off');
        $('.screen .door').html(info.door_open ? 'Open' : 'Closed');
        $('.screen .time').html(info.formatted_time);
        $('.screen .power').html(info.power_string);
      }

      if (barcodes.length){
        var barcodeHTML = "";
        $.each(barcodes, function(i, val){
          barcodeHTML += "<li>" + val + "</li>"
        });
        $('.barcodes ul.barcodes-list').html(barcodeHTML);
        $('.barcodes').show();
      } else {
        $('.barcodes').hide();
      }
    });
  }

  setInterval(updateInfo, 1000);
});
