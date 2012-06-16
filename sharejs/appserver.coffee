connect = require('connect')
express = require('express')
sharejs = require('share').server
cookie = require('cookie')
url = require('url')
RedisSessionStore = require('connect-redis')(connect)
redis = require('redis').createClient()
u_ = require('underscore')


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


server.use '/login', (req, res) ->
  req.session.user = (req.session.user or {})
  headers = 'Content-Type': 'application/json'
  if req.method is 'GET'
    res.writeHead 200, headers
    return res.end(JSON.stringify(req.session.user) + '\n')
  else if req.method isnt 'POST'
    res.writeHead 405, headers
    return res.end('{"error": "HTTP POST the login credentials here."')
  email = req.body.email
  password = req.body.password
  if validPassword(email, password)
    req.session.user = email: req.body.email
    res.writeHead 200, headers
    res.end JSON.stringify(req.session.user) + '\n'
  else
    req.session.user = {}
    res.writeHead 403, headers
    res.end '{"error": "invalid email or password"}'


server.use '/documents/', (req, res, next) ->
  path = url.parse(req.url).path
  fragments = path.split('/')
  if fragments.length isnt 2
    res.writeHead 404, {}
    return res.end("invalid path: #{path}")
  doc_id = fragments[1]
  if doc_id.length is 0
    return redis.keys 'ShareJS:doc:*', (err, keys) ->
      if err
        res.writeHead 500, {}
        return res.end('redis error')
      res.writeHead 200, {}
      doc_keys = u_.map keys, (k) -> k.slice 12
      res.end doc_keys.join('\n')
  options = path: __dirname + '/static/index.html'
  connect.static.send req, res, next, options


validPassword = (email, password) ->
  email is 'test@example.com' and password is 'password'

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