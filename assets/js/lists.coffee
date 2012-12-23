utils = documaraUtils

renderListLink = _.template($("#doc-template").text())

documentId = ->
  regex = /^\/lists\/([-a-zA-Z0-9]+)/
  matches = regex.exec(document.location.pathname)
  if matches and matches.length is 2
    matches[1]
  else
    null


openDocument = ->
  sharejs.open documentId(), "json", (err, doc) ->
    if err
      console.log "Error connecting ShareJS:", err
      utils.showPage "login"  if err is "forbidden"
      return

    console.log(doc)
    utils.attachTextbox doc.at('title'), $('#list-title')


setupUI = ->
  unless documentId()
    utils.showPage "list-page"
    $.ajax "/api/documents/",
      success: (docs) ->
        docs = _.filter docs, (doc) -> doc.type is 'list'
        console.log "TODO: display loaded lists"
        console.log docs
        $allLists = $('#all-docs')
        _.each docs, (doc) ->
          doc.selected = if (doc.id is documentId())
            'selected'
          else
            ''
          $allLists.append renderListLink(doc)
      statusCode:
        401: ->
          utils.showPage "login"
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


createNewList = () ->
  initialData =
    title: '',
    type: 'list'
  $.post '/api/documents/', initialData, (doc) ->
    if doc.id
      window.location = "/lists/#{doc.id}"



$('#create-new-list').live 'click', (e) ->
  e.preventDefault()
  createNewList()


$(document).ready ->
  jQuery.ajaxSetup cache: false
  setupUI()