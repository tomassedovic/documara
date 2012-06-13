$('#login-page form').live('submit', function() {
  var $form = $(this);
  var params = $form.serialize();
  $.ajax({
    url: $form.attr('action'),
    type: 'POST',
    data: params,
    success: function() {
      openDocument();
    },
    error: function() {
      $form.find('.alert').show();
    }
  });
  return false;
});

function document_id() {
  /* Get the database ID of the list. */
  var regex = /^\/documents\/([-a-zA-Z0-9]+)/
  return regex.exec(document.location.pathname)[1]
}

function openDocument() {
  sharejs.open(document_id(), 'text', function(err, doc) {
    if(err) {
      console.log("Error connecting ShareJS:", err);
      if(err === 'forbidden') {
        $('#login-page').show();
        $('#document-page').hide();
      }
    } else {
      var $editor = $('#editor');
      $editor.attr('disabled', false);

      // ShareJS doesn't support jQuery objects, we must use the native DOM
      // representation for $editor
      doc.attach_textarea($editor[0]);
      $('#login-page').hide();
      $('#document-page').show();
    }
  });
}


$(document).ready(function() {
  openDocument();
})
