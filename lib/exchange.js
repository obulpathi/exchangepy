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
};

Exchange.prototype.bind_pg_watcher = function ()
{
	var self = this;
	var db_scout, pg = require('pg'), config = require('./../config.js');

	var conString = "tcp://" + config.pg.username + ":" + config.pg.password + "@" + config.pg.host + "/" + config.pg.db;
	db_scout = new pg.Client(conString);
	db_scout.connect();

	db_scout.on('notification', function (msg)
	{
		// Disassembling string msg.payload

		var parts = msg.payload.split(',');

		// What tables involved - orders_limit, balances, matched

		var table = parts.pop();

		switch (table){

		}

	});

	db_scout.query("LISTEN scout");
}