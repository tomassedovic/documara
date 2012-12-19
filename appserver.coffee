connect = require('connect')
assets = require('connect-assets')
RedisSessionStore = require('connect-redis')(connect)
cookie = require('cookie')
express = require('express')
sharejs = require('share').server
u_ = require('underscore')

api = require('./api')
dbi = require('./dbi')

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

documentChanged = (action, login, doc_id) ->
  throttledReindex = throttledReindex ? {}
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
    if not api.isSessionLoggedIn(session)
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



server = express.createServer()
server.use connect.logger()
server.use connect.cookieParser()
server.use connect.bodyParser()

sessionConfig =
  key: 'sid'
  secret: 'my secret here'
  store: new RedisSessionStore

server.use connect.session(sessionConfig)

server.use assets()
server.use connect.static("#{__dirname}/static")

# Inform connect-assets that it should compile this coffeescript file
js('application')


server.get '/documents/:id', (req, res) ->
  res.sendfile __dirname + '/static/index.html'


sharejsOptions =
  db:
    type: 'redis'
  auth: authenticateSharejs

sharejs.attach server, sharejsOptions
db = dbi.connect server.model
api.connectServer(server, db)

PORT = process.argv[2] or 8080
server.listen PORT
console.log "Server running at port #{PORT}"
