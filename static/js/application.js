var renderDocumentListItem = Mustache.compile($('#list-item-template').text());

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




function match(pattern, text) {
  var normalized = function(text) {
    return accent_fold(text.toLowerCase());
  };
  return normalized(text).indexOf(normalized(pattern)) >= 0;
}

$('#searchbox').live('focusin', function(e) {
  /* For some reason the text isn't selected when pressing the Up key
   * from the list unless the timeout is here.
   */
  setTimeout(function() { $('#searchbox').select(); }, 10);
});

$('#searchbox').live('keyup', function(e) {
  if(e.which == 40) {
    e.preventDefault();
    $('#documents li:visible:first a').addClass('focus', true).focus();
  }

  var pattern = $('#searchbox').val();
  var filter = function(index, element) {
    var $e = $(element);
    $e.toggle(match(pattern, $e.find('a h3').text()));
  };
  _.defer(function() { $('#documents li').each(filter); });
});

$('#documents li a').live('keydown', function(e) {
  if(e.which == 40) {
    e.preventDefault();
    var $next = $(this).parent().nextAll(':visible').first().find('a');
    $next.focus();
  }
  if(e.which == 38) {
    e.preventDefault();
    var $prev = $(this).parent().prevAll(':visible').first().find('a');
    if($prev.length == 0) $prev = $('#searchbox');
    $prev.focus();
  }
});

$('#documents li a').live('focusin', function(e) {
  $(this).addClass('selected');
});

$('#documents li a').live('focusout', function(e) {
  $(this).removeClass('selected');
});




function showPage(id) {
  $('section').hide();
  console.log('showing page #' + id);
  $('section#' + id).show();
  $('#user-info').toggle(id !== 'login');
}

function setupUI() {
  if(!document_id()) {
    showPage('document-index');
    $.ajax('/api/documents/', {
      success: function(docs) {
        var $documents = $('#documents');
        jQuery.each(docs, function(index, doc) {
          var $li = $('<li />');
          doc.human_time = (new XDate(doc.created)).toLocaleDateString();
          $li.html($(renderDocumentListItem(doc)));
          $documents.append($li);
        });
        $('#searchbox').select();
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
  jQuery.ajaxSetup({ cache: false });
  setupUI();
});
