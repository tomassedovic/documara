var connect = require('connect');
var sharejs = require('share').server;
var parseCookie = require('connect').utils.parseCookie;

var server = connect(
  connect.logger(),
  connect.cookieParser(),
  connect.session({ secret: 'my secret here' }),
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

function getSession(headers) {
  // TODO: read the cookie, decrypt it and load the session
  //console.log(headers);
  return {};
}

function isLoggedIn(session) {
  // TODO: look up the user in the session, verify their login status
  return false;
}

function authenticateSharejs(agent, action) {
  session = getSession(agent.headers);
  if(isLoggedIn(session)) {
    return action.accept();
  } else {
    return action.reject();
  }
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
