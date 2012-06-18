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
        var now = (new XDate(true)).toISOString();
        doc.set({body: '', title: '', created: now, last_modified: now});
      }
      // ShareJS doesn't support jQuery objects, we must use the native DOM
      // representation for $editor
      doc.at('body').attach_textarea($editor[0]);
      var $title = $('#title');
      attach_textbox(doc.at('title'), $title);
      attachLastModified($editor, $title, doc.at('last_modified'));
      showPage('document-show');
    }
  });
}

function attachLastModified($editor, $title, doc) {
  var last_checked_version = {};
  last_checked_version.body = $editor.val();
  last_checked_version.title = $title.val();
  var timeout = 10 * 1000;
  setTimeout(function() {
    if(last_checked_version.body !== $editor.val() ||
       last_checked_version.title !== $title.val()) {
      last_checked_version.body = $editor.val();
      last_checked_version.title = $title.val();
      var now = (new XDate).toISOString();
      doc.set(now);
    }
    setTimeout(arguments.callee, timeout);
  }, timeout);
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
          jQuery.get('/doc/' + doc_id, function(doc) {
            var $a = $('a[href="/documents/' + doc_id + '"]');
            $a.text(doc.title);
          });
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
