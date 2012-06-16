connect = require('connect')
express = require('express')
sharejs = require('share').server
cookie = require('cookie')
url = require('url')
RedisSessionStore = require('connect-redis')(connect)
redis = require('redis').createClient()
u_ = require('underscore')
db = require('./dbi').connect()


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


server.get '/api/documents/', (req, res) ->
  sendJSON res, ['todo', 'thingy'], 200


sendJSON = (res, data, code) ->
  res.header 'Content-Type', 'application/json; charset=utf-8'
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

authenticateSharejs = (agent, action) ->
  session = getSession agent.headers, (session) ->
    if isLoggedIn(session)
      action.accept()
    else
      action.reject()


sharejsOptions =
  db:
    type: 'redis'
  auth: authenticateSharejs

sharejs.attach server, sharejsOptions


PORT = process.argv[2] or 8080
server.listen PORT
console.log "Server running at port #{PORT}"
