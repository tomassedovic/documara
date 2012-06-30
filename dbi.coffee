redis = require('redis').createClient();
crypto = require 'crypto'
bcrypt = require 'bcrypt'
u_ = require 'underscore'
XDate = require 'xdate'
async = require 'async'


format_date = (s) ->
  (new XDate(s)).toUTCString("yyyy-MM-dd'T'HH:mm:ss.fffzzz")


dbi = (con, model) ->
  result =

    createUser: (login, password, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin login, (err, user_id) ->
        if err
          return callback err, null
        if user_id
          return callback { error: 'user already exists'}, null
        user =
          email: login
          password: bcrypt.hashSync(password, bcrypt.genSaltSync())
        user_id = crypto.randomBytes(4).toString('hex')
        # TODO: test that the user_id doesn't exist already
        con.hmset "documara:user:#{user_id}", user, (err, ok) ->
          if err
            return callback err, null
          con.hmset "documara:login-user-mapping", login, user_id, (err, ok) ->
            if err
              return callback err, null
            delete user['password']
            return callback null, user


    getUser: (login, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin login, (err, user_id) ->
        if err
          return callback err, null
        unless user_id
          return callback { error: 'unknown user' }, null
        con.hgetall "documara:user:#{user_id}", (err, user) ->
          if err
            return callback err, null
          return callback null, user


    validCredentials: (login, password, callback) ->
      callback = (() ->) unless callback?
      @getUser login, (err, user) ->
        if err
          return callback null, false
        unless user
          return callback null, false
        return callback null, bcrypt.compareSync(password, user.password)


    createDocument: (owner_login, doc, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin owner_login, (err, user_id) ->
        if err
          return callback err, null
        unless user_id
          return callback { error: 'unknown user' }, null
        doc_id = crypto.randomBytes(4).toString('hex')
        index_key = "documara:user:#{user_id}:documents_by_last_modified"
        current_time = (new XDate(true))
        if u_.isEmpty doc
          doc = {}
        unless doc.created
          doc.created = format_date(current_time)
        unless doc.last_modified
          doc.last_modified = doc.created
        timestamp = (new XDate(doc.last_modified)).getTime()
        async.series [
          (cb) ->
            model.create doc_id, 'json', cb
          (cb) ->
            model.applyOp doc_id, {op: [{p: [], oi: doc}], v: 0}, cb
          (cb) ->
            con.zadd index_key, timestamp, doc_id, cb
        ], (err, results) ->
          return callback err, doc_id

    userHasDocument: (owner_login, doc_id, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin owner_login, (err, user_id) ->
        if err
          return callback err, null
        unless user_id
          return callback { error: 'unknown user' }, null
        index_key = "documara:user:#{user_id}:documents_by_last_modified"
        con.zscore index_key, doc_id, (err, score) ->
          console.log err, score
          if err
            return callback err, null
          return callback null, score?


    getDocument: (doc_id, callback) ->
      callback = (() ->) unless callback?
      model.getSnapshot doc_id, (err, snapshot) ->
        if err
          return callback err, null
        return callback null, sharejs_doc.snapshot

    documents: (owner_login, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin owner_login, (err, user_id) ->
        if err
          return callback err, null
        unless user_id
          return callback { error: 'unknown user' }, null
        index_key = "documara:user:#{user_id}:documents_by_last_modified"
        con.zrevrange index_key, 0, -1, (err, docs) ->
          if err
            return callback err, null
          return callback null, docs


    updateIndex: (owner_login, doc_id, callback) ->
      callback = (() ->) unless callback?
      async.waterfall [
        (cb) =>
          @findUserIdFromLogin owner_login, (err, user_id) ->
            if err
              return cb err, null
            index_key = "documara:user:#{user_id}:documents_by_last_modified"
            cb null, index_key, doc_id
        @updateDocumentIndexScore
      ], (err, result) ->
        return callback err, result

    updateDocumentIndexScore: (index_key, doc_id, callback) ->
      callback = (() ->) unless callback?
      async.waterfall [
        (cb) ->
          model.getVersion doc_id, cb
        (version, cb) ->
          unless version and version > 0
            return cb 'Version is zero, no need to update', null
          model.getOps doc_id, version - 1, null, cb
        (ops, cb) ->
          if u_.isEmpty ops
            return cb 'did not receive any snapshots', null
          last_op = u_.last ops
          timestamp = last_op.meta.ts
          con.zadd index_key, timestamp, doc_id, cb
      ], (err, result) ->
        return callback err, true


    findUserIdFromLogin: (login, callback) ->
      callback = (() ->) unless callback?
      con.hmget "documara:login-user-mapping", login, (err, values) ->
        if err
          return callback err, null
        user_id = values[0]
        return callback null, user_id


  return result

isShareJSModel = (model) ->
  required_functions = ['create', 'applyOp', 'getSnapshot']
  model and u_.all(required_functions, (f) -> f of model)


exports.connect = (model) ->
  unless isShareJSModel(model)
    throw new Error('You must specify a ShareJS model object.')
  return dbi(redis, model)
