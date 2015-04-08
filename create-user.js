//
//
//
// Create a new user in the database.
//
// Redis is expected to be running, the app doesn't have to. You need to pass
// the EMAIL and PASSWORD environment variables.
//
// Example:
// $ EMAIL=me@example.com PASSWORD=1234 node create-user.js
//
//
//


redis = require('redis').createClient();
crypto = require('crypto')
bcrypt = require('bcrypt')

email = process.env.EMAIL
password = process.env.PASSWORD

user = {
  email: email,
  password: bcrypt.hashSync(password, bcrypt.genSaltSync())
};

callback = function(err, ok) {
  if(err) {
    console.error("Error:", err);
    process.exit(1);
  } else {
    console.info("Success:", ok);
    process.exit(0);
  }
};

redis.hmget("documara:login-user-mapping", email, function(err, values) {
  if(err) {
    return callback(err, null);
  }
  if(values[0] !== null) {
    return callback("User '" + email + "' already exists.", null);
  }
  user_id = crypto.randomBytes(4).toString('hex');
  redis.hmset("documara:user:" + user_id, user, function(err, ok) {
    if(err) {
      return callback("User ID '" + user_id + "' already exists.", null);
    }
    redis.hmset("documara:login-user-mapping", email, user_id, function(err, ok) {
      if(err) {
        return callback("User '" + email + "' could not be created.", null);
      }
      return callback(null, "User '" + email + "' was created.");
    });
  });
});
