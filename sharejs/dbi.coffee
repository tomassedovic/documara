redis = require('redis').createClient();
crypto = require 'crypto'
bcrypt = require 'bcrypt'

dbi = (con) ->
  result =

    users: (callback) ->
      callback = (() ->) unless callback?
      con.keys '*', (err, data) ->
        return callback err, data


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


    documents: (callback) ->
      return callback {}


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
