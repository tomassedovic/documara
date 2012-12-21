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

setupMiddleware = (app) ->
  app.use connect.logger()
  app.use connect.cookieParser()
  app.use connect.session(sessionConfig)
  app.use connect.bodyParser()




app = express()

sessionConfig =
  key: 'sid'
  store: new RedisSessionStore

switch app.get 'env'
  when 'development'
      console.log('Running in development mode')

      sessionConfig.secret = 'my secret here'
      setupMiddleware app
      PORT = process.argv[2] or 8080

      app.use connect.static("#{__dirname}/static")
      app.use assets()

      app.get '/', (req, res) ->
        res.redirect '/documents/'


      # compile `assets/documents.coffee`
      js('documents')

      app.get '/documents/', (req, res) ->
        res.sendfile __dirname + '/static/documents.html'

      app.get '/documents/:id', (req, res) ->
        res.sendfile __dirname + '/static/documents.html'

      # compile `assets/lists.coffee`
      js('lists')

      app.get '/lists/', (req, res) ->
        res.sendfile __dirname + '/static/lists.html'

      app.get '/lists/:id', (req, res) ->
        res.sendfile __dirname + '/static/lists.html'

  when 'production'
      console.log('Running in production mode')

      settings_path = "#{__dirname}/settings.json"
      fs = require('fs')
      s = fs.readFileSync(settings_path, 'utf-8')
      settings = JSON.parse(s)

      sessionConfig.secret = settings.session_secret
      setupMiddleware app
      PORT = settings.port
  else
    console.error "Unknown environment: '#{app.get('env')}'"


sharejsOptions =
  db:
    type: 'redis'
  auth: authenticateSharejs

sharejs.attach app, sharejsOptions
db = dbi.connect app.model
api.attach(app, db)

app.listen PORT
console.log "Server running at port #{PORT}"
