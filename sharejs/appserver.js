var connect = require('connect');
var sharejs = require('share').server;
var parseCookie = require('connect').utils.parseCookie;
var cookie = require('cookie');

var sessionStore = new connect.session.MemoryStore();

var server = connect(
  connect.logger(),
  connect.cookieParser(),
  connect.session({
    key: 'sid',
    secret: 'my secret here',
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

function validPassword(email, password) {
  return (email === 'test@example.com' && password === 'password');
}

function getSession(headers, callback) {
  try {
    parsed = cookie.parse(headers.cookie);
    // TODO: probably not very robust. Read connect's code and extract the
    // session key properly
    session_key = parsed.sid.slice(2, 26);
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
