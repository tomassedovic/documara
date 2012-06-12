var connect = require('connect');
var sharejs = require('share').server;

var server = connect(
  connect.logger(),
  connect.static(__dirname + '/static')
);


var options = {
  db: {
    type: 'redis'
  }
};

sharejs.attach(server, options);

var PORT = process.argv[2] || 8080;
server.listen(PORT);
console.log('Server running at port ' + PORT);
