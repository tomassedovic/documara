connect = require('connect')
express = require('express')
sharejs = require('share').server
cookie = require('cookie')
assets = require('connect-assets')
url = require('url')
RedisSessionStore = require('connect-redis')(connect)
redis = require('redis').createClient()
u_ = require('underscore')
async = require('async')
XDate = require 'xdate'
dbi = require('./dbi')


sessionConfig =
  key: 'sid'
  secret: 'my secret here'
  store: new RedisSessionStore


server = express.createServer()
server.use connect.logger()
server.use connect.cookieParser()
server.use connect.session(sessionConfig)
server.use connect.bodyParser()
server.use assets()
server.use connect.static("#{__dirname}/static")

# Inform connect-assets that it should compile this coffeescript file
js('application')

MustBeLoggedInError = (() ->)
InvalidCredentialsError = (() ->)

requireLoggedIn = (req, res, next) ->
  if isSessionLoggedIn(req.session)
    return next()

  [email, password] = getBasicAuthCredentials(req)
  unless email and password
    return next(new MustBeLoggedInError)

  db.validCredentials email, password, (err, valid) ->
    if valid
      req.session.user = { email: email }
      return next()
    else
      return next(new InvalidCredentialsError)

server.error (err, req, res, next) ->
  if err instanceof MustBeLoggedInError
    sendJSON res, {"error": "you must be logged in"}, 401
  else if err instanceof InvalidCredentialsError
    sendJSON res, {"error": "invalid email or password"}, 401
  else
    next err


server.get '/login', (req, res) ->
  sendJSON res, req.session.user or {}, 200


server.post '/login', (req, res) ->
  req.session.user = (req.session.user or {})
  email = req.body.email
  password = req.body.password
  db.validCredentials email, password, (err, valid) ->
    if valid
      req.session.user = email: req.body.email
      sendJSON res, req.session.user, 200
    else
      req.session.user = {}
      sendJSON res, {"error": "invalid email or password"}, 401


server.post '/logout', (req, res) ->
  req.session.user = {}
  res.redirect '/'


server.get '/documents/:id', (req, res) ->
  res.sendfile __dirname + '/static/index.html'


server.post '/api/documents/', requireLoggedIn, (req, res) ->
  doc =
    body: req.body.body or ''
    title: req.body.title or ''
  db.createDocument req.session.user.email, doc, (err, doc_id) ->
    if err
      return sendJSON res, { error: err }, 500
    return sendJSON res, { id: doc_id }, 201


server.get '/api/documents/', requireLoggedIn, (req, res) ->
  processTimeFilter = (filter, query_name) ->
    unless req.query[query_name]
      return
    d = XDate(req.query[query_name], true)
    if d.valid()
      filter[query_name] = d.getTime()
    else if req.query[query_name] is 'all'
      filter[query_name] = 0
    else
      throw new Error(query_name)

  filter = {}
  try
    processTimeFilter filter, 'created_since'
    processTimeFilter filter, 'modified_since'
    processTimeFilter filter, 'published_since'
  catch err
    return sendJSON res, { error: err.message}, 400

  db.documents req.session.user.email, filter, (err, docs) ->
    if err
      return sendJSON res, { error: err }, 500
    async.map docs
    , (doc_id, callback) ->
      db.getDocument req.session.user.email, doc_id, (err, doc) ->
        if req.query.full_doc == 'true'
          result = u_.extend({}, doc)
        else
          result = u_.pick(doc, 'title', 'created', 'last_modified', 'published', 'slug')
        result.id = doc_id
        result.author = req.session.user.email
        return callback err, result
    , (err, result) ->
      if err
        return sendJSON res, { error: err }, 500
      return sendJSON res, result, 200


server.get '/api/documents/:doc_id', requireLoggedIn, (req, res) ->
  doc_id = req.params.doc_id
  db.getDocument req.session.user.email, doc_id, (err, doc) ->
    if err?
      return sendJSON res, { error: err }, 404
    doc.id = doc_id
    doc.author = req.session.user.email
    return sendJSON res, doc, 200

sendJSON = (res, data, code) ->
  res.header 'Content-Type', 'application/json; charset=utf-8'
  res.header 'Cache-Control', 'no-cache, no-store, max-age=0'
  res.header 'Expires', 'Mon, 01 Jan 1990 00:00:00 GMT'
  res.charset = 'utf-8'
  res.send JSON.stringify(data) + '\n', code

getSession = (headers, callback) ->
  try
    parsed = cookie.parse(headers.cookie)
    [store, secret] = [sessionConfig.store, sessionConfig.secret]

    session_key = connect.utils.parseSignedCookie(parsed.sid, secret)
    store.get session_key, (err, session) ->
      callback session
  catch ex
    console.warn 'Exception inside getSession:', ex
    return callback {}

isSessionLoggedIn = (session) ->
  return session and session.user and session.user.email

getBasicAuthCredentials = (req) ->
  basic_auth = req.headers['authorization']
  if basic_auth? and not u_.isEmpty(basic_auth)
    decoded = (new Buffer(basic_auth.split(' ')[1], 'base64')).toString('ascii')
    i = decoded.indexOf(':')
    return [decoded.slice(0, i), decoded.slice(i + 1)]
  else
    return [null, null]



throttledReindex = {}

documentChanged = (action, login, doc_id) ->
  console.log("document changed: #{doc_id}, action: #{action}")
  unless doc_id of throttledReindex
    reindexDoc = () ->
      console.log "rebuilding index for document: #{doc_id}"
      db.updateIndex login, doc_id, (err, success) ->
        console.log "index rebuild for #{doc_id} finished. error msg: #{err}"
    throttledReindex[doc_id] = u_.throttle reindexDoc, (2 * 1000)
  throttledReindex[doc_id]()

authenticateSharejs = (agent, action) ->
  getSession agent.headers, (session) ->
    if not isSessionLoggedIn(session)
      return action.reject()
    if action.type is 'connect'
      return action.accept()

    db.userHasDocument session.user.email, action.docName, (err, exists) ->
      if err
        return action.reject()
      unless exists
        return action.reject()
      action.accept()
      if action.type in ['create', 'update', 'delete']
        documentChanged(action.type, session.user.email, action.docName)


sharejsOptions =
  db:
    type: 'redis'
  auth: authenticateSharejs

sharejs.attach server, sharejsOptions
db = dbi.connect server.model


PORT = process.argv[2] or 8080
server.listen PORT
console.log "Server running at port #{PORT}"
