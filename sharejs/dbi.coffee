redis = require('redis').createClient();
crypto = require 'crypto'
bcrypt = require 'bcrypt'
u_ = require 'underscore'

dbi = (con) ->
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
        con.sadd "documara:user:#{user_id}:documents", doc_id, (err) ->
          if err
            return callback err, null
          return callback null, doc_id

    documents: (owner_login, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin owner_login, (err, user_id) ->
        if err
          return callback err, null
        unless user_id
          return callback { error: 'unknown user' }, null
        con.smembers "documara:user:#{user_id}:documents", (err, docs) ->
          if err
            return callback err, null
          return callback null, docs


    updateIndex: (owner_login, doc_id, callback) ->
      callback = (() ->) unless callback?
      @findUserIdFromLogin owner_login, (err, user_id) =>
        if err
          return callback err, null
        index_key = "documara:user:#{user_id}:documents_by_last_modified"
        @updateDocumentIndexScore index_key, doc_id, callback


    updateDocumentIndexScore: (index_key, doc_id, callback) ->
      callback = (() ->) unless callback?
      con.lrange "ShareJS:ops:#{doc_id}", -1, -1, (err, ops) ->
        if err
          return callback err, null
        if u_.isEmpty ops
          return callback 'ops are empty', null
        last_op = JSON.parse(ops[0])
        timestamp = last_op.meta.ts
        con.zadd index_key, timestamp, doc_id, (err) ->
          return callback err, true


    findUserIdFromLogin: (login, callback) ->
      callback = (() ->) unless callback?
      con.hmget "documara:login-user-mapping", login, (err, values) ->
        if err
          return callback err, null
        user_id = values[0]
        return callback null, user_id


  return result


exports.connect = () ->
  return dbi(redis)
