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


app = express()

session_secret = process.env.SESSION_SECRET ? require('crypto').randomBytes(20).toString('hex')
port = process.env.PORT ? 8080
serve_assets = app.get('env') is 'development'
REDIS_PORT = process.env.REDIS_PORT ? 6379
REDIS_HOST = process.env.REDIS_HOST ? '127.0.0.1'

dayInMs = 24 * 60 * 60 * 1000

sessionConfig =
  key: 'sid'
  secret: session_secret
  store: new RedisSessionStore({port: REDIS_PORT, host: REDIS_HOST})
  cookie:
    maxAge: 7 * dayInMs

app.use connect.logger()
app.use connect.cookieParser()
app.use connect.session(sessionConfig)
app.use connect.bodyParser()

if serve_assets
  console.log('Running in development mode, serving static assets')

  app.use connect.static("#{__dirname}/static")
  app.use assets()

  app.get '/', (req, res) ->
    res.redirect '/documents/'

  renderPage = (req, res) ->
    js('utils')
    js('documents')
    js('lists')
    res.sendfile __dirname + '/static/documents.html'

  app.get '/documents/', renderPage
  app.get '/documents/:id', renderPage
  app.get '/lists/', renderPage
  app.get '/lists/:id', renderPage


sharejsOptions =
  db:
    type: 'redis'
    port: REDIS_PORT
    hostname: REDIS_HOST
  auth: authenticateSharejs


if "--create-user" in process.argv
  # create user from EMAIL and PASSWORD environment variables
  redis = require('redis').createClient(REDIS_PORT, REDIS_HOST)
  crypto = require('crypto')
  bcrypt = require('bcrypt')

  callback = (err, ok) ->
    if err
      console.error("Error:", err)
      process.exit(1)
    else
      console.info("Success:", ok)
      process.exit(0)

  email = process.env.EMAIL
  password = process.env.PASSWORD
  if (not email) or (not password)
    callback "Missing EMAIL or PASSWORD"

  user =
    email: email,
    password: bcrypt.hashSync(password, bcrypt.genSaltSync())

  redis.hmget "documara:login-user-mapping", email, (err, values) ->
    if err
      return callback(err, null)
    # values is `[null]` if not previously present, `["some email"]` otherwise
    if values[0]
      return callback("User '#{email}' already exists.", null)
    user_id = crypto.randomBytes(4).toString('hex')
    redis.hmset "documara:user:" + user_id, user, (err, ok) ->
      if err
        return callback("User ID '#{user_id}' already exists.", null)
      redis.hmset "documara:login-user-mapping", email, user_id, (err, ok) ->
        if err
          return callback("User '#{email}' could not be created.", null)
        return callback(null, "User '#{email}' was created.")

else
  # run server
  sharejs.attach app, sharejsOptions
  db = dbi.connect(app.model, REDIS_PORT, REDIS_HOST)
  api.attach(app, db)

  # If we're run by `coffee --watch`, close the current server before listening
  # on port
  process.documara_server.close() if process.documara_server?.close?

  process.documara_server = app.listen port
  console.log "Server running at port #{port}"
