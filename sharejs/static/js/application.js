$(document).ready(function() {
  sharejs.open('thingy', 'text', function(err, doc) {
    if(err) {
      console.log("Error connecting ShareJS:", err);
      if(err === 'forbidden') {
        window.location = '/login';
      }
    } else {
      var $editor = $('#editor');
      $editor.attr('disabled', false);

      // ShareJS doesn't support jQuery objects, we must use the native DOM
      // representation for $editor
      doc.attach_textarea($editor[0]);
    }
  })
})
