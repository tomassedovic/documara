$('#login form').live('submit', function() {
  var $form = $(this);
  var params = $form.serialize();
  $.ajax({
    url: $form.attr('action'),
    type: 'POST',
    data: params,
    success: function() {
      setupUI();
    },
    error: function() {
      $form.find('.alert').show();
    }
  });
  return false;
});

function attach_textbox(doc, $textbox) {
  $textbox.val(doc.getText());
  $textbox.live('keyup', function() {
    doc.set($textbox.val());
  });

  // This doesn't work for some reason. We need a callback on when this thing
  // changes
  doc.on('child op', function() {
    console.log('title changed');
  });
}

function document_id() {
  /* Get the database ID of the list. */
  var regex = /^\/documents\/([-a-zA-Z0-9]+)/;
  var matches = regex.exec(document.location.pathname);
  if(matches && matches.length === 2) {
    return matches[1];
  } else {
    return null;
  }
}

function openDocument() {
  sharejs.open(document_id(), 'json', function(err, doc) {
    if(err) {
      console.log("Error connecting ShareJS:", err);
      if(err === 'forbidden') {
        showPage('login');
      }
    } else {
      var $editor = $('#editor');
      $editor.attr('disabled', false);
      if(!doc.get()) {
        // This is a newly-created document. Initialize it:
        doc.set({body: '', title: ''});
      }
      var subdoc = doc.at('body');
      // ShareJS doesn't support jQuery objects, we must use the native DOM
      // representation for $editor
      subdoc.attach_textarea($editor[0]);
      attach_textbox(doc.at('title'), $('#title'));
      showPage('document-show');
    }
  });
}

function showPage(id) {
  $('section').hide();
  console.log('section #' + id);
  $('section#' + id).show();
}

function setupUI() {
  if(!document_id()) {
    showPage('document-index');
    $.ajax('/api/documents/', {
      success: function(docs) {
        var $documents = $('#documents');
        jQuery.each(docs, function(index, doc_id) {
          var $li = $('<li />');
          var $a = $('<a href="/documents/'+ doc_id + '">' + doc_id + '</a>');
          $li.append($a);
          $documents.append($li);
        });
      },
      statusCode: {
        401: function() { showPage('login'); }
      }
    });
    return;
  }
  openDocument();
}


$(document).ready(function() {
  setupUI();
});
