share = require 'share'
db = require('./dbi').connect(share.server.createModel({db: {type: 'redis'}}))
u_ = require 'underscore'
XDate = require 'xdate'
fs = require 'fs'
async = require 'async'


data = JSON.parse(fs.readFileSync('/home/thomas/tmp/documara-redis/dump.json').toString())
console.log u_.keys data.rows[0].value
user = 'test@example.com'

format_date = (s) ->
  (new XDate(s)).toUTCString("yyyy-MM-dd'T'HH:mm:ss.fffzzz")

migrateDocument = (row, callback) ->
  doc = row.value
  unless doc.type
    doc.type = 'text'
  unless doc.type is 'text'
    console.log doc.type, u_.keys(doc)
  doc.created = format_date(doc.created)
  doc.last_modified = format_date(doc.lastModified or doc.created)
  if doc.published
    doc.published = format_date(doc.published)
  doc = u_.pick doc, 'title', 'body', 'slug', 'created', 'last_modified', 'published'
  console.log "#{doc.created}, #{doc.last_modified}, #{doc.published}, #{doc.slug}"

  db.createDocument user, doc, (err, doc_id) ->
    console.log "created document #{doc_id}"
    callback(err)


async.forEach data.rows
, migrateDocument
, (err) ->
  console.log 'done'
  if err?
    console.log 'error:', err
  process.exit()
