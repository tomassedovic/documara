redis = require('redis').createClient();
crypto = require 'crypto'
bcrypt = require 'bcrypt'
u_ = require 'underscore'
XDate = require 'xdate'
async = require 'async'


format_date = (s) ->
  (new XDate(s)).toUTCString("yyyy-MM-dd'T'HH:mm:ss.fffzzz")


by_created_index_key = (user_id) ->
  "documara:user:#{user_id}:documents_by_created"
by_modified_index_key = (user_id) ->
  "documara:user:#{user_id}:documents_by_last_modified"
by_published_index_key = (user_id) ->
  "documara:user:#{user_id}:documents_by_published"


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
        current_time = (new XDate(true))
        if u_.isEmpty doc
          doc = {}
        unless doc.created
          doc.created = format_date(current_time)
        unless doc.last_modified
          doc.last_modified = doc.created
        async.series [
          (cb) ->
            model.create doc_id, 'json', cb
          (cb) ->
            model.applyOp doc_id, {op: [{p: [], oi: doc}], v: 0}, cb
          (cb) ->
            timestamp = (new XDate(doc.last_modified)).getTime()
            con.zadd by_modified_index_key(user_id), timestamp, doc_id, cb
          (cb) ->
            timestamp = (new XDate(doc.created)).getTime()
            con.zadd by_created_index_key(user_id), timestamp, doc_id, cb
          (cb) ->
            unless doc.published
              return cb()
            timestamp = (new XDate(doc.published)).getTime()
            con.zadd by_published_index_key(user_id), timestamp, doc_id, cb
        ], (err, results) ->
          return callback err, doc_id

    userHasDocument: (owner_login, doc_id, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin owner_login, (err, user_id) ->
        if err
          return callback err, null
        unless user_id
          return callback { error: 'unknown user' }, null
        con.zscore by_modified_index_key(user_id), doc_id, (err, score) ->
          console.log err, score
          if err
            return callback err, null
          return callback null, score?


    getDocument: (owner_login, doc_id, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin owner_login, (err, user_id) ->
        if err
          return callback err, null
        unless user_id
          return callback { error: 'unknown user' }, null
        model.getSnapshot doc_id, (err, sharejs_doc) ->
          if err
            return callback err, null
          con.zscore by_modified_index_key(user_id), doc_id, (err, timestamp) ->
            if err
              return callback err, null
            doc = (sharejs_doc?.snapshot || {})
            doc.last_modified = format_date(parseInt(timestamp))
            return callback null, doc



    # Filter values:
    # created_since (int)  -- documents as old or newer than timestamp
    # modified_since (int)  -- documents that were changed since timestamp
    # published_since (int)  -- public documents that were published since timestamp
    # limit (int) -- return at most that many documents
    # The documents will be sorted by the modification date. The most recently
    # modified first
    documents: (owner_login, filter, callback) ->
      callback = (() ->) unless callback?
      async.waterfall [
        (cb) =>
          @findUserIdFromLogin owner_login, (err, user_id) ->
            if err
              return cb err
            unless user_id
              return cb { error: 'unknown user' }
            return cb null, user_id
        (user_id, cb) =>
          @docsByCreated user_id, filter.created_since, (err, docs) ->
            return cb err, user_id, docs
        (user_id, docs_by_created, cb) =>
          @docsByModified user_id, filter.modified_since, (err, docs) ->
            return cb err, user_id, docs_by_created, docs
        (user_id, docs_by_created, docs_by_modified, cb) =>
          unless filter.published_since?
            # Don't call the database, return the docs_by_created instead When
            # the user doesn't specify `published_since` we should not filter
            # out docs that are private. But the docs_by_published index doesn't
            # return private documents. By returning the created documents
            # instead, this amounts to NOP in the final set intersection
            # operation.
            return cb null, docs_by_created, docs_by_modified, docs_by_created
          @docsByPublished user_id, filter.published_since, (err, docs) ->
            return cb err, docs_by_created, docs_by_modified, docs
        (docs_by_created, docs_by_modified, docs_by_published, cb) =>
            return cb null, u_.intersection(docs_by_modified, docs_by_published,
                                            docs_by_created)
      ], (err, result) ->
        if err
          console.error 'error', err
        return callback err, result


    docsByCreated: (user_id, timestamp, callback) ->
      min = if timestamp then timestamp else '-inf'
      key = by_created_index_key(user_id)
      con.zrevrangebyscore key, '+inf', min, (err, docs) ->
        return callback err, docs

    docsByModified: (user_id, timestamp, callback) ->
      min = if timestamp then timestamp else '-inf'
      key = by_modified_index_key(user_id)
      con.zrevrangebyscore key, '+inf', min, (err, docs) ->
        return callback err, docs

    docsByPublished: (user_id, timestamp, callback) ->
      min = if timestamp then timestamp else '-inf'
      key = by_published_index_key(user_id)
      con.zrevrangebyscore key, '+inf', min, (err, docs) ->
        return callback err, docs


    updateIndex: (owner_login, doc_id, callback) ->
      callback = (() ->) unless callback?
      async.waterfall [
        (cb) =>
          @findUserIdFromLogin owner_login, (err, user_id) ->
            if err
              return cb err, null
            cb null, user_id, doc_id
        @updateDocumentIndexScore
      ], (err, result) ->
        return callback err, result

    updateDocumentIndexScore: (user_id, doc_id, callback) ->
      callback = (() ->) unless callback?
      async.waterfall [
        (cb) ->
          model.getVersion doc_id, cb
        (version, cb) ->
          unless version and version > 0
            return cb null, []  # version is zero: no need to update
          model.getOps doc_id, version - 1, null, cb
        (ops, cb) ->
          if u_.isEmpty ops
            return cb null
          last_op = u_.last ops
          timestamp = last_op.meta.ts
          con.zadd by_modified_index_key(user_id), timestamp, doc_id, cb
        (_, cb) ->
          model.getSnapshot doc_id, cb
        (doc, cb) ->
          snapshot = doc.snapshot
          unless snapshot
            return cb 'received null snapshot'
          unless snapshot.published and snapshot.slug
            return cb null
          pubdate = new XDate(snapshot.published)
          unless pubdate.valid()
            return cb 'invalid publication date'
          timestamp = pubdate.getTime()
          con.zadd by_published_index_key(user_id), timestamp, doc_id, cb
      ], (err, result) ->
        if err
          console.error 'updateDocumentIndexScore error:', err
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
