var io = require('socket.io').listen(80);

io.sockets.on('connection', function (socket) {
	socket.emit('auth');
	socket.on('login', function (data) {
		if ( data.login == 'santa' ){
			console.log('Logged in');

			socket.on('cmd', function (data) {
				console.log(data);
			});
		}else{
			socket.disconnect();
		}
	});
});