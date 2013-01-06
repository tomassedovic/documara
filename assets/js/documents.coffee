utils = documaraUtils

renderDocumentListItem = _.template($("#list-item-template").text())


documentId = ->
  regex = /^\/documents\/([-a-zA-Z0-9]+)/
  matches = regex.exec(document.location.pathname)
  if matches and matches.length is 2
    matches[1]
  else
    null


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
      utils.showPage "login"  if err is "forbidden"
      return

    $editor = $("#editor")
    $editor.attr "disabled", false
    doc.at("body").attach_textarea $editor[0]
    $title = $("#title")
    utils.attachTextbox doc.at("title"), $title
    $('#publish').live 'click', publishCallback(doc)
    utils.showPage "document-show"
    renderFooter(doc.snapshot)


setupUI = ->
  $("#login form").on "submit", ->
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

  unless documentId()
    utils.showPage "document-index"
    $.ajax "/api/documents/?type=text",
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
          utils.showPage "login"
    return
  openDocument()


$("#searchbox").live "focusin", (e) ->
  setTimeout (-> $("#searchbox").select()), 10

$("#searchbox").live "keyup", (e) ->
  if e.which is utils.keys.enter
    $("#documents li:visible:first a").click()
    return

  if e.which is utils.keys.esc
    $(this).val('')

  if e.which is utils.keys.down_arrow
    e.preventDefault()
    $("#documents li:visible:first a").addClass("focus", true).focus()
    return

  pattern = $("#searchbox").val().trim()
  filter = (index, element) ->
    $e = $(element)
    $e.toggle utils.matchTextDwim(pattern, $e.find("a h3").text())
  _.defer ->
    $('#new-document').toggle(not _.isEmpty(pattern)).find('h3').text(pattern)
    $("#documents li").slice(1).each filter

$("#documents li a").live "keydown", (e) ->
  if e.which is utils.keys.down_arrow
    e.preventDefault()
    $next = $(this).parent().nextAll(":visible").first().find("a")
    $next.focus()
  if e.which is utils.keys.up_arrow
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


publishCallback = (doc) ->
  return ->
    published = utils.parseHumanDate $('#published-date').val()
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
  return unless utils.currentSection() is 'documents'
  jQuery.ajaxSetup cache: false
  setupUI()