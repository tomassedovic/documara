var connect = require('connect');
var sharejs = require('share').server;
var parseCookie = require('connect').utils.parseCookie;
var cookie = require('cookie');
var url = require('url');
var RedisSessionStore = require('connect-redis')(connect);
var redis = require('redis').createClient();
var u_ = require('underscore');

var sessionStore = new RedisSessionStore;
var sessionSecret = 'my secret here';

var server = connect(
  connect.logger(),
  connect.cookieParser(),
  connect.session({
    key: 'sid',
    secret: sessionSecret,
    store: sessionStore,
  }),
  connect.bodyParser(),
  connect.static(__dirname + '/static')
);

server.use('/login', function(req, res) {
  req.session.user = (req.session.user || {});
  headers = {
    'Content-Type': 'application/json',
  }
  if(req.method === 'GET') {
    res.writeHead(200, headers);
    return res.end(JSON.stringify(req.session.user) + '\n');
  } else if(req.method !== 'POST') {
    res.writeHead(405, headers);
    return res.end('{"error": "HTTP POST the login credentials here."');
  }

  var email = req.body.email;
  var password = req.body.password;
  if(validPassword(email, password)) {
    req.session.user = { email: req.body.email };
    res.writeHead(200, headers);
    return res.end(JSON.stringify(req.session.user) + '\n');
  } else {
    req.session.user = {};
    res.writeHead(403, headers);
    return res.end('{"error": "invalid email or password"}');
  }
});

server.use('/documents/', function(req, res, next) {
  var path = url.parse(req.url).path;
  var fragments = path.split('/');
  if(fragments.length !== 2) {
    res.writeHead(404, {});
    return res.end('invalid path: ' + path);
  }

  var doc_id = fragments[1];
  if(doc_id.length === 0) {
    return redis.keys('ShareJS:doc:*', function(err, keys) {
      if(err) {
        res.writeHead(500, {});
        return res.end('redis error');
      }

      res.writeHead(200, {});
      doc_keys = u_.map(keys, function(k) { return k.slice(12) });
      return res.end(doc_keys.join('\n'));
    });
  }

  var options = { path: __dirname + '/static/index.html' }
  connect.static.send(req, res, next, options)
});

function validPassword(email, password) {
  return (email === 'test@example.com' && password === 'password');
}

function getSession(headers, callback) {
  try {
    var parsed = cookie.parse(headers.cookie);
    var session_key = connect.utils.parseSignedCookie(
          parsed.sid, sessionSecret);
    sessionStore.get(session_key, function(err, session) {
      return callback(session)
    });
  }
  catch(ex) {
    return callback({});
  }
}

function isLoggedIn(session) {
  return session && session.user && session.user.email;
}

function authenticateSharejs(agent, action) {
  session = getSession(agent.headers, function(session) {
    if(isLoggedIn(session)) {
      return action.accept();
    } else {
      return action.reject();
    }
  });
}

var options = {
  db: {
    type: 'redis'
  },
  auth: authenticateSharejs
};

sharejs.attach(server, options);

var PORT = process.argv[2] || 8080;
server.listen(PORT);
console.log('Server running at port ' + PORT);
