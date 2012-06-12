var connect = require('connect');
var sharejs = require('share').server;
var parseCookie = require('connect').utils.parseCookie;

var server = connect(
  connect.logger(),
  connect.static(__dirname + '/static')
);

server.use('/login', function(req, res) {
  // TODO: serve the login form, verify credentials and set auth session cookie
  headers = {
    'Content-Type': 'text/html',
    'Set-Cookie': 'hello=world; Path=/; HttpOnly'
  }
  res.writeHead(200, headers);
  res.end('<h1>Please login</h1>');
});

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
