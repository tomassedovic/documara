renderDocumentListItem = Mustache.compile($("#list-item-template").text())


documentId = ->
  regex = /^\/documents\/([-a-zA-Z0-9]+)/
  matches = regex.exec(document.location.pathname)
  if matches and matches.length is 2
    matches[1]
  else
    null


attachTextbox = (doc, $textbox) ->
  $textbox.val doc.getText()
  $textbox.live "keyup", ->
    doc.set $textbox.val()
  doc.on "child op", ->
    console.log "title changed"


attachLastModified = ($editor, $title, doc) ->
  last_checked_version = {}
  last_checked_version.body = $editor.val()
  last_checked_version.title = $title.val()
  timeout = 10 * 1000
  setTimeout (->
    if last_checked_version.body isnt $editor.val() or last_checked_version.title isnt $title.val()
      last_checked_version.body = $editor.val()
      last_checked_version.title = $title.val()
      now = (new XDate).toISOString()
      doc.set now
    setTimeout arguments.callee, timeout
  ), timeout


openDocument = ->
  sharejs.open documentId(), "json", (err, doc) ->
    if err
      console.log "Error connecting ShareJS:", err
      showPage "login"  if err is "forbidden"
      return

    $editor = $("#editor")
    $editor.attr "disabled", false
    doc.at("body").attach_textarea $editor[0]
    $title = $("#title")
    attachTextbox doc.at("title"), $title
    attachLastModified $editor, $title, doc.at("last_modified")
    $('#publish').live 'click', publishCallback(doc)
    showPage "document-show"
    renderFooter(doc.snapshot)


# Matches text to a given pattern ignoring case and character accents
matchTextDwim = (pattern, text) ->
  normalized = (text) ->
    accent_fold text.toLowerCase()
  normalized(text).indexOf(normalized(pattern)) >= 0


showPage = (id) ->
  $("section").hide()
  console.log "showing page #" + id
  $("section#" + id).show()
  $.getJSON "/login", (data) ->
    name = data and (data.name or data.email)
    if name
      $("#user-info .username").text name
      $("#user-info").show()


setupUI = ->
  unless documentId()
    showPage "document-index"
    $.ajax "/api/documents/",
      success: (docs) ->
        $documents = $("#documents")
        jQuery.each docs, (index, doc) ->
          $li = $("<li />")
          doc.human_time = (new XDate(doc.created)).toLocaleDateString()
          $li.html $(renderDocumentListItem(doc))
          $documents.append $li
        $("#searchbox").select()
      statusCode:
        401: ->
          showPage "login"
    return
  openDocument()


$("#login form").live "submit", ->
  $form = $(this)
  params = $form.serialize()
  $.ajax
    url: $form.attr("action")
    type: "POST"
    data: params
    success: ->
      setupUI()
    error: ->
      $form.find(".alert").show()
  return false

$("#searchbox").live "focusin", (e) ->
  setTimeout (-> $("#searchbox").select()), 10

$("#searchbox").live "keyup", (e) ->
  if e.which is 40
    e.preventDefault()
    $("#documents li:visible:first a").addClass("focus", true).focus()
  pattern = $("#searchbox").val().trim()
  filter = (index, element) ->
    $e = $(element)
    $e.toggle matchTextDwim(pattern, $e.find("a h3").text())
  _.defer ->
    $('#new-document').toggle(not _.isEmpty(pattern)).find('h3').text(pattern)
    $("#documents li").slice(1).each filter

$("#documents li a").live "keydown", (e) ->
  if e.which is 40
    e.preventDefault()
    $next = $(this).parent().nextAll(":visible").first().find("a")
    $next.focus()
  if e.which is 38
    e.preventDefault()
    $prev = $(this).parent().prevAll(":visible").first().find("a")
    $prev = $("#searchbox")  if $prev.length is 0
    $prev.focus()

$("#documents li a").live "focusin", (e) ->
  $(this).addClass "selected"

$("#documents li a").live "focusout", (e) ->
  $(this).removeClass "selected"

$('#set-current-time').live 'click', () ->
  $('#published-date').val (new XDate).toString('d MMMM yyyy')

$('#new-document').live 'click', (e) ->
  e.preventDefault()
  $.post '/api/documents/', { title: $('#searchbox').val().trim() }, (doc) ->
    if doc.id
      window.location = "/documents/#{doc.id}"


# Parse the date given in format "24 March 2012" (local time) and return a UTC
# XDate object
parseHumanDate = (s) ->
  months = XDate.locales[''].monthNames
  parts = _.compact s.split ' '

  year = parseInt(parts[2])
  day = parseInt(parts[0])
  unless $.isNumeric(year) and $.isNumeric(day)
    return null
  month = _.indexOf months, parts[1]
  unless _.all([year, day, month], (n) -> n >= 0)
    return null
  result = XDate(year, month, day, 0, 0, 0, 1, true)
  unless result.valid()
    return null
  return result


publishCallback = (doc) ->
  return ->
    published = parseHumanDate $('#published-date').val()
    slug = _.compact($('#slug').val().trim().split(' ')).join('-')
    unless published and slug
      return alert 'enter correct slug and date'
    doc.setAt ['published'], published.toISOString()
    doc.setAt ['slug'], slug
    renderFooter(doc.snapshot)


renderFooter = (snapshot) ->
  $form = $('#publish-form')
  $info = $('#publication-info')
  if snapshot.published and snapshot.slug
    $form.hide()
    $info.show()
    date = (new XDate(snapshot.published))
    $info.find('a').attr('href', "/public/#{date.toString('yyyy-MM-dd')}/#{snapshot.slug}")
    $info.find('time').text(date.toLocaleDateString())
  else
    $info.hide()
    $form.show()


$(document).ready ->
  jQuery.ajaxSetup cache: false
  setupUI()