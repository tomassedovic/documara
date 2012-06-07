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

server.listen(8000);
console.log('Server running at port 8000');
