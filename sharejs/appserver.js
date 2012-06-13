var connect = require('connect');
var sharejs = require('share').server;
var parseCookie = require('connect').utils.parseCookie;

var server = connect(
  connect.logger(),
  connect.bodyParser(),
  connect.static(__dirname + '/static')
);

server.use('/login', function(req, res) {
  // TODO: verify credentials and set auth session cookie
  if(req.method !== 'POST') {
    res.writeHead(405, {});
    return res.end('HTTP POST the login credentials here.');
  }
  var email = req.body.email;
  var password = req.body.password;
  headers = {
    'Content-Type': 'text/html',
  }
  if(validPassword(email, password)) {
    headers['Content-Type'] = 'application/json';
    headers['Set-Cookie'] = 'hello=world; Path=/; HttpOnly';
    res.writeHead(200, headers);
    return res.end('{"email": "' + email + '"}');
  } else {
    res.writeHead(403, headers);
    return res.end('{"error": "invalid email or password"}');
  }
});

function validPassword(email, password) {
  return (email === 'test@example.com' && password === 'password');
}

function getSession(headers) {
  // TODO: read the cookie, decrypt it and load the session
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
