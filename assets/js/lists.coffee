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
        $('#items input').eq(path[0]).prop('checked', op.oi)
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

    $('#items input').live 'change', () ->
      $this = $(this)
      checked = $this.prop('checked')
      index = $this.parent('li').index()
      itemsDoc.at([index, 'finished']).set(checked)

appendListItem = (item) ->
  this.uniqueIdCounter = (this.uniqueIdCounter ? 0) + 1
  desc = (_.range(Math.floor(Math.random() * 10)).map (n) -> 'wordy').join(' ')
  item = _.extend({id: this.uniqueIdCounter, description: desc}, item)
  $el = $(renderListItem(item))
  $("#items").append($el)
  makeListSortable($el)
  # $el.find('.title').on 'click', (e) ->
  #   # TODO: show an edit textbox instead
  #   $(this).css({background: 'blue'})


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



makeListSortable = ($el) ->
  sign = (num) ->
    if num < 0
      -1
    else if num > 0
      1
    else
      0

  shouldSwap = ($dragged, offset, $target, direction) ->
    return false unless $target?
    return false if direction is 0

    smallerHeight = Math.min($target.height(), $dragged.height())
    tolerance = Math.floor(smallerHeight / 2)
    if direction is 1
      difference = (offset.top + $dragged.height()) - $target.offset().top
    else
      difference = ($target.offset().top + $target.height()) - offset.top

    return (difference >= tolerance)

  getNeighbour = ($el, direction) ->
    if (direction is 1) and !($el.is(':last-child'))
      return $el.next()
    else if (direction is -1) and !($el.is(':first-child'))
      return $el.prev()

  swap = ($dragged, $target, direction) ->
    return if direction is 0
    if direction is 1
      $dragged.insertAfter($target)
    else
      $dragged.insertBefore($target)

  draggedHelper = () ->
    $dragged = $(this)
    $dragged.clone().css({
      width: "#{$dragged.width()}px"
      height: "#{$dragged.height()}px"
      background: "white"
    })

  options =
    axis: 'y'
    containment: 'parent'
    helper: draggedHelper
    distance: 3
    stack: 'li'
    zIndex: 1000
    start: (event, ui) ->
      $(this).data('pos', ui.offset)
      $(this).data('lastTop', ui.offset.top)
      $(this).css({visibility: 'hidden'})

    drag: (event, ui) ->
      $this = $(this)
      # direction:
      # 0: no change
      # 1: moved down
      # -1: moved up
      direction = sign(ui.offset.top - $this.data('lastTop'))
      $this.data('lastTop', ui.offset.top)

      $target = getNeighbour($this, direction)

      if shouldSwap($this, ui.offset, $target, direction)
        swap($this, $target, direction)

    stop: (event, ui) ->
      # We must clone and reinsert the helper because the original one will be
      # deleted immediately after the function exists -- before the animation
      # colud start
      $original = $(this)
      $helper = ui.helper.clone().appendTo($('#items'))
      delta = $original.offset().top - ui.offset.top
      if delta > 0
        animationValue = "+=#{delta}"
      else
        animationValue = "-=#{-delta}"
      $helper.animate {top: animationValue}, 100, () ->
        $original.css({visibility: 'visible'})
        $helper.remove()

  $el.draggable(options)


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
  animate($('#items input:checked').parent())

$('#new-item').live 'keyup', (e) ->
  if e.which is utils.keys.enter
    $('#add-item').click()


$(document).ready ->
  return unless utils.currentSection() is 'lists'
  jQuery.ajaxSetup cache: false
  setupUI()