# Export the functions here under the `documaraUtils` namespace
self = {}
exports = (exports ? this)
exports.documaraUtils = self

# Matches text to a given pattern ignoring case and character accents
self.matchTextDwim = matchTextDwim = (pattern, text) ->
  normalized = (text) ->
    accent_fold text.toLowerCase()
  normalized(text).indexOf(normalized(pattern)) >= 0

# Parse the date given in format "24 March 2012" (local time) and return a UTC
# XDate object
self.parseHumanDate = parseHumanDate = (s) ->
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

self.showPage = showPage = (id) ->
  $("#sections li").removeClass('active')
  $("#sections a[rel='#{currentSection()}']").parent('li').addClass('active')
  $("section").hide()
  console.log "showing page #" + id
  $("section#" + id).show()
  $.getJSON "/login", (data) ->
    name = data and (data.name or data.email)
    if name
      $("#user-info .username").text name
      $("#user-info").show()

self.attachTextbox = attachTextbox = (doc, $textbox) ->
  $textbox.val doc.getText()
  $textbox.live "keyup", ->
    doc.set $textbox.val()

self.keys = keys =
  enter: 13
  esc: 27
  down_arrow: 40
  up_arrow: 38

self.currentSection = currentSection = () ->
  pathSegments = document.location.pathname.split('/')
  if _.size(pathSegments) > 1
    pathSegments[1]
  else
    alert('Cannot get the current section')

# Returns an `listItemAdded($li)` closure. It must be called when a list item is added.
# The `itemMovedCallback(from, to)` is called when the user changed an item order.
self.listSortable = listSortable = ($list, itemMovedCallback) ->
  itemMovedCallback ?= (->)
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
    $helper = $dragged.clone()
      .addClass('drag-helper')
      .css({
        width: "#{$dragged.width()}px"
        height: "#{$dragged.height()}px"
      })
    return $helper

  listItemAdded = ($li) ->
    options =
      axis: 'y'
      containment: 'parent'
      helper: draggedHelper
      distance: 3
      stack: 'li'
      zIndex: 1000
      start: (event, ui) ->
        $(this)
          .data('pos', $(this).index())
          .data('lastTop', ui.offset.top)
          .css({visibility: 'hidden'})

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
        from = $original.data('pos')
        to = $original.index()
        if from isnt to
          setTimeout((-> itemMovedCallback(from, to)), 0)
        $helper = ui.helper.clone().appendTo($('#items'))
        delta = $original.offset().top - ui.offset.top
        if delta > 0
          animationValue = "+=#{delta}"
        else
          animationValue = "-=#{-delta}"
        $helper.animate {top: animationValue}, 100, () ->
          $original.css({visibility: 'visible'})
          $helper.remove()
    $li.draggable(options)

  $list.children('li').each -> listItemAdded($(this))

  return listItemAdded