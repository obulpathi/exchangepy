var Account = require('./account.js');

var Exchange = module.exports = function ()
{
	this.accounts = [];
}

Exchange.prototype.bind_socket_io_events = function (io)
{
	var self = this;
	self.io = io;

	self.io.sockets.on('connection', function (socket)
	{
		socket.on('login', function (data)
		{
			var account = new Account();

			account.login(data, function (err)
			{
				if ( err ) {
					socket.emit('error', {msg : err});
					socket.disconnect();
					return;
				}

				socket.emit('loggedin');

				self.accounts[account.id] = socket.id;

				socket.on('cmd', function (data)
				{
					account.cmd(data, function (err, result)
					{
						if ( err ) {
							console.log(err);
							return;
						}

						switch ( data.payload.action ) {
							case 'new_order':
								account.new_order(data.payload, function (err, order_id)
								{
									if ( err ) {
										socket.emit('error', {msg : err});
										return;
									}

									socket.emit('new_order', {id : order_id});
								});
								break;
						}
					});
				});
			});
		});
	});

	this.bind_pg_watcher();
};

Exchange.prototype.bind_pg_watcher = function ()
{
	if ( this.io == null ) throw new Error('SocketIO missing');

	var self = this;
	var db_scout, pg = require('pg'), config = require('./../config.js'), db = require('./db').db();

	var conString = "tcp://" + config.pg.username + ":" + config.pg.password + "@" + config.pg.host + "/" + config.pg.db;
	db_scout = new pg.Client(conString);
	db_scout.connect();

	db_scout.on('notification', function (msg)
	{
		// Disassembling string msg.payload

		var parts = msg.payload.split(',');

		// What tables involved - orders_limit, balances, matched, symbols

		var table = parts.shift();

		switch ( table ) {

			// Global

			case 'symbols':
				self.io.sockets.volatile.emit('bidask', {symbol : parts[0], bid : parts[1], ask : parts[2]});
				break;
			case 'matched':
				self.io.sockets.volatile.emit('matched', {symbol : parts[0], price : parts[1], amount : parts[2]});

			// Private:

			case 'balances':
				if ( self.accounts[parts[0]] != null ) {
					self.io.sockets.socket(self.accounts[parts[0]]).emit('balance', {symbol : parts[1], balance : parts[2] });
				}
				break;
			case 'orders_limit':
				if ( self.accounts[parts[0]] != null ) {
					db.query({
						name   : 'select order',
						text   : "SELECT * FROM orders_limit WHERE id = $1",
						values : [parts[1]]
					}, function (err, result)
					{
						self.io.sockets.socket(self.accounts[parts[0]]).emit('orders', result.rows[0]);
					});
				}
				break;
		}

	});

	db_scout.query("LISTEN scout");
}