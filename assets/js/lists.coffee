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
    doc.connection.on 'error', (e) ->
      console.log "CONNECTION ERROR, closing the document...", e
      $('#items li').slideUp()
      $('#items').append $("<p>Lost connection to the server.</p>").css({color: 'red'})
      $('<a href="#">I understand, now show my items again.</a>')
        .on 'click', ->
          $('#items li').slideDown()
          $(this).remove()
        .appendTo $('#items')
      doc.close()

    utils.attachTextbox doc.at('title'), $('#list-title')

    itemsDoc = doc.at('items')
    itemsDoc.set([]) if _.isEmpty(itemsDoc.get())
    _.each itemsDoc.get(), (item) ->
      appendListItem(item)

    updateSortable = utils.listSortable $('#items'), (from, to) ->
      itemsDoc.move(from, to)

    # TODO: remove all the listeners on disconnect
    doc.at().on 'child op', (path, op) ->
      console.log('DOC CHILD OP')
      console.log path
      console.log op
    itemsDoc.on 'child op', (path, op) ->
      console.log('ITEMS CHILD OP')
      console.log path
      console.log op
      if (path.length is 2) and (path[1] is 'finished')
        $('#items .finished').eq(path[0]).toggleClass('active', op.oi)
      if (path.length is 2) and (path[1] is 'title')
        $('#items .title').eq(path[0]).text(op.oi)
      if (path.length is 2) and (path[1] is 'description')
        $('#items .description').eq(path[0]).text(op.oi)
    itemsDoc.on 'insert', (pos, item) ->
      console.log('LIST ITEM INSERTED')
      updateSortable(appendListItem(item))
    itemsDoc.on 'replace', (pos, was, now) ->
      console.log("LIST ITEM CHANGED")
      console.log(pos, was, now)
    itemsDoc.on 'move', (from, to) ->
      $items = $('#items li')
      $el = $items.eq(from)
      $target = $items.eq(to)
      if from > to
        $el.insertBefore($target)
      else
        $el.insertAfter($target)
    itemsDoc.on 'delete', (pos, removedData) ->
      $('#items li').eq(pos).remove()
      setElementsVisibility()

    $("#add-item").live 'click', () ->
      item =
        title: $('#new-item').val()
        finished: false
      itemsDoc.push(item)
      updateSortable(appendListItem(item))
      $('#new-item').val('')

    $('#items').on 'click', '.finished', () ->
      $this = $(this)
      finished = not $this.hasClass('active')
      index = $this.parent('li').index()
      itemsDoc.at([index, 'finished']).set(finished)

    $editBox = $('<input type="text" />')
        .appendTo($('body'))

    hideEditBox = ->
      $editBox.offset({top: 0, left: 0}).css({visibility: 'hidden'})

    updateTitle = ->
      newTitle = $editBox.val()
      $title = $editBox.data('attachedTo')
      $title.text(newTitle)
      index = $title.parents('li').index()
      itemsDoc.at([index, 'title']).set(newTitle)
      hideEditBox()

    $editBox
      .on 'keyup', (e) ->
        if e.which is utils.keys.enter
          updateTitle()
        if e.which is utils.keys.esc
          hideEditBox()
      .on 'blur', ->
        updateTitle()

    hideEditBox()


    $('#items').on 'click', '.title', () ->
      $this = $(this)
      $editBox
        .data('attachedTo', $this)
        .css({height: $this.height()})
        .offset($this.offset())
        .val($this.text())
        .css({visibility: 'visible'})
        .focus()


    defaultDescriptionHeight = 100

    $descriptionEditBox = $('<textarea />')
      .appendTo($('body'))
      .height(defaultDescriptionHeight)
      .css({visibility: 'hidden'})

    hideDescriptionEditBox = ->
      $descriptionEditBox
        .offset({top: 0, left: 0})
        .css({visibility: 'hidden'})
      $description = $descriptionEditBox.data('attachedTo').find('.description')
      $description.addClass('hidden') if _.isEmpty($description.text().trim())


    showDescriptionEditBox = ($li) ->
      $description = $li.find('.description')
      if $description.hasClass('hidden')
        $description
          .removeClass('hidden')
          .height(defaultDescriptionHeight)

      offset = $description.offset()
      $descriptionEditBox
        .data('attachedTo', $li)
        .offset(offset)
        .outerHeight($description.outerHeight())
        .width($description.width())
        .val($li.find('.description').text().trim())
        .css({
          'font': $description.css('font')
          'padding': $description.css('padding')
          'margin': $description.css('margin')
        })
        .css({visibility: 'visible'})
        .focus()

    $('#items').on 'click', '.add-description', ->
      showDescriptionEditBox($(this).parents('li'))

    $('#items').on 'click', '.description', ->
      showDescriptionEditBox($(this).parents('li'))

    updateDescription = ->
        newDescription = $descriptionEditBox.val()
        $li = $descriptionEditBox.data('attachedTo')
        originalDescription = $li.find('.description').text()
        if newDescription isnt originalDescription
          $li.find('.description').text(newDescription)
          itemsDoc.at([$li.index(), 'description']).set(newDescription)
        hideDescriptionEditBox()

    $descriptionEditBox
      .on 'keyup', (e) ->
        if e.which is utils.keys.esc
          hideDescriptionEditBox()
        if e.ctrlKey and (e.which is utils.keys.enter)
          updateDescription()
      .on 'blur', ->
        updateDescription()

    $('#items').on 'click', '.remove-item', ->
      index = $(this).parents('li').index()
      $goner = $('#items li').eq(index)
      # I normally prefer faster animations, but this is a destructive operation
      # It's better to let the user know what's happening.
      $goner.fadeOut 300, () ->
        itemsDoc.at([index]).remove()
        $goner.remove()


appendListItem = (item) ->
  this.uniqueIdCounter = (this.uniqueIdCounter ? 0) + 1
  item = _.extend({id: this.uniqueIdCounter}, item)
  $el = $(renderListItem(item))
  $("#items").append($el)
  setElementsVisibility()
  return $el


setupUI = ->
  $.ajax "/api/documents/?type=list",
    success: (docs) ->
      utils.showPage "list-page"
      $allLists = $('#all-docs ul')
      docs = _.sortBy docs, (d) -> d.title
      _.each docs, (doc) ->
        doc.selected = if (doc.id is documentId())
          'active'
        else
          ''
        $allLists.append renderListLink(doc)
      setElementsVisibility()
      openDocument() if documentId()
    statusCode:
      401: ->
        utils.showPage "login"


setElementsVisibility = ->
  $('#document-area').toggleClass('empty', $('#items li').length is 0)


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

hideFinished = () ->
  !!$('#hide-finished').data('hide-finished')


$("#hide-finished").live 'click', () ->
  $button = $(this)

  hide = !hideFinished()
  $button.data('hide-finished', hide)
  if(hide)
    animate = ($el) -> $el.slideUp('fast')
    text = $button.data('text-show-all')
  else
    animate = ($el) -> $el.slideDown('fast')
    text = $button.data('text-hide-finished')
  $button.text(text)
  animate($('#items .finished.active').parent())

$('#new-item').live 'keyup', (e) ->
  if e.which is utils.keys.enter
    $('#add-item').click()


$(document).ready ->
  return unless utils.currentSection() is 'lists'
  jQuery.ajaxSetup cache: false
  setupUI()