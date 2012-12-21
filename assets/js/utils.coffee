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
