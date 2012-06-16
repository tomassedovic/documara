redis = require('redis').createClient();

dbi = (con) ->
  result =

    users: (callback) ->
      con.keys '*', (err, data) ->
        return callback err, data

    createUser: (email, password, callback) ->
      return callback {}

    documents: (callback) ->
      return callback {}


  return result


exports.connect = () ->
  return dbi(redis)
