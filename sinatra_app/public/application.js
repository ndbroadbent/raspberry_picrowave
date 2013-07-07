$(function(){
  $(document).on('click', 'button', function(event) {
    var buttonName = $(event.currentTarget).data('name');
    $.get('/button/' + buttonName);
  });

  source = new EventSource('/events');
  source.addEventListener('open', function(e) {
    console.log("Connection opened");
  });

  source.addEventListener('error', function(e) {
    console.log("Connection error");
    if (e.readyState == EventSource.CLOSED) {
      console.log("Connection closed");
    }
  });

  source.addEventListener('message', function(e) {
    data = JSON.parse(e.data)
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
});
