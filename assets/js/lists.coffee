utils = documaraUtils

_.templateSettings.variable = 'd'
renderListLink = _.template($("#doc-template").text())
renderListItem = _.template($("#item-template").text())

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

    itemsDoc = doc.at('items')
    itemsDoc.set([]) if _.isEmpty(itemsDoc.get())
    _.each itemsDoc.get(), (item) ->
      appendListItem(item)

    doc.at().on 'child op', (path, op) ->
      console.log('DOC CHILD OP')
      console.log path
      console.log op
    itemsDoc.on 'child op', (path, op) ->
      console.log('ITEMS CHILD OP')
      console.log path
      console.log op
    itemsDoc.on 'insert', (pos, item) ->
      console.log('LIST ITEM INSERTED')
      appendListItem(item)
    itemsDoc.on 'replace', (pos, was, now) ->
      console.log("LIST ITEM CHANGED")
      console.log(pos, was, now)
    itemsDoc.on 'move', (from, to) ->
      console.log('LIST ITEM MOVED')
      console.log(from, to)
    itemsDoc.on 'delete', (pos, removedData) ->
      console.log('LIST ITEM DELETED')
      console.log(pos, removedData)
      # No plans for deleting items yet, but this is how it should work:
      # $('#items li').eq(pos).remove()

    $("#add-item").live 'click', () ->
      item =
        title: $('#new-item').val()
        finished: false
      itemsDoc.push(item)
      appendListItem(item)
      $('#new-item').val('')

    $("#hide-finished").live 'click', () ->
      # TODO: toggle the finished items

appendListItem = (item) ->
  this.uniqueIdCounter = (this.uniqueIdCounter ? 0) + 1
  item = _.extend({id: this.uniqueIdCounter}, item)
  $("#items").append renderListItem(item)


setupUI = ->
  unless documentId()
    utils.showPage "list-page"
    $.ajax "/api/documents/",
      success: (docs) ->
        docs = _.filter docs, (doc) -> doc.type is 'list'
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
    title: ''
    type: 'list'
    items: []
  $.post '/api/documents/', initialData, (doc) ->
    if doc.id
      window.location = "/lists/#{doc.id}"



$('#create-new-list').live 'click', (e) ->
  e.preventDefault()
  createNewList()


$(document).ready ->
  jQuery.ajaxSetup cache: false
  setupUI()