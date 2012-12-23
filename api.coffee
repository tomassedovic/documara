async = require('async')
XDate = require('xdate')
us = require('underscore')


exports.isSessionLoggedIn = isSessionLoggedIn = (session) ->
  return session and session.user and session.user.email

exports.attach = (server, db) ->

  server.use (err, req, res, next) ->
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


  server.post '/api/documents/', requireLoggedIn, (req, res) ->
    doc =
      body: ''
      title: ''
      type: null
    us.extend doc, req.body
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
            result = us.extend({}, doc)
          else
            result = us.pick(doc, 'title', 'created', 'last_modified', 'published', 'slug', 'type')
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
  res.set('Content-Type', 'application/json; charset=utf-8')
  res.set('Cache-Control', 'no-cache, no-store, max-age=0')
  res.set('Expires', 'Mon, 01 Jan 1990 00:00:00 GMT')
  res.charset = 'utf-8'
  res.send JSON.stringify(data) + '\n', code

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

getBasicAuthCredentials = (req) ->
  basic_auth = req.headers['authorization']
  if basic_auth? and not u_.isEmpty(basic_auth)
    decoded = (new Buffer(basic_auth.split(' ')[1], 'base64')).toString('ascii')
    i = decoded.indexOf(':')
    return [decoded.slice(0, i), decoded.slice(i + 1)]
  else
    return [null, null]
