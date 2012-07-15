var Exchange = module.exports = function ()
{
}

Exchange.prototype.bind_socket_io_events = function (io)
{
	this.io = io;
	this.io.sockets.on('connection', function (socket)
	{
		socket.emit('auth');
		socket.on('login', function (data)
		{
			if (data.login == 'santa') {
				console.log('Logged in');

				socket.on('cmd', function (data)
				{
					console.log(data);
				});
			} else {
				socket.disconnect();
			}
		});
	});
};