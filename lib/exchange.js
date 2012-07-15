var Account = require('./account.js');

var Exchange = module.exports = function ()
{
	this.accounts = [];
}

Exchange.prototype.bind_socket_io_events = function (io)
{
	var self = this;
	this.io = io;
	this.io.sockets.on('connection', function (socket)
	{
		socket.on('login', function (data)
		{
			var account = new Account();

			account.login(data, function (err)
			{
				if ( err ) {
					socket.emit('error',{msg:err});
					socket.disconnect();
					return;
				}

				socket.emit('loggedin');

				self.accounts[account.id] = socket.id;

				socket.on('cmd', function (data)
				{
					console.log(data);
				});
			});
		});
	});
};