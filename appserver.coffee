connect = require('connect')
express = require('express')
sharejs = require('share').server
cookie = require('cookie')
url = require('url')
RedisSessionStore = require('connect-redis')(connect)
redis = require('redis').createClient()
u_ = require('underscore')
async = require('async')
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
server.use connect.static("#{__dirname}/static")


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
      sendJSON res, 403, {"error": "invalid email or password"}


server.post '/logout', (req, res) ->
  req.session.user = {}
  res.redirect '/'


server.get '/documents/:id', (req, res) ->
  res.sendfile __dirname + '/static/index.html'


server.post '/documents/', (req, res) ->
  if isLoggedIn(req.session)
    doc =
      body: ''
      title: ''
    db.createDocument req.session.user.email, doc, (err, doc_id) ->
      if err
        return sendJSON res, { error: err }, 500
      res.redirect "/documents/#{doc_id}"
  else
    return sendJSON res, { error: 'not logged in'}, 401


server.get '/api/documents/', (req, res) ->
  if isLoggedIn(req.session)
    db.documents req.session.user.email, (err, docs) ->
      if err
        return sendJSON res, { error: err }, 500
      async.map docs
      , (doc_id, callback) ->
        server.model.getSnapshot doc_id, (err, doc) ->
          doc = (doc?.snapshot || {})
          result = u_.pick(doc, 'title', 'created', 'last_modified')
          result.id = doc_id
          return callback err, result
      , (err, result) ->
        if err
          return sendJSON res, { error: err }, 500
        return sendJSON res, result, 200
  else
    return sendJSON res, { error: 'not logged in'}, 401


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

isLoggedIn = (session) ->
  session and session.user and session.user.email


throttledReindex = {}

documentChanged = (action, login, doc_id) ->
  console.log("document changed: #{doc_id}, action: #{action}")
  unless doc_id of throttledReindex
    reindexDoc = () ->
      console.log "rebuilding index for document: #{doc_id}"
      db.updateIndex(login, doc_id)
    throttledReindex[doc_id] = u_.throttle reindexDoc, (60 * 1000)
  throttledReindex[doc_id]()

authenticateSharejs = (agent, action) ->
  getSession agent.headers, (session) ->
    if not isLoggedIn(session)
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
