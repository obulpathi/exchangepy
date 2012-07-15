var pg = require('pg'), crypto = require('crypto'), config = require('./../config.js');

var conString = "tcp://" + config.pg.username + ":" + config.pg.password + "@" + config.pg.host + "/" + config.pg.db;

var pg_client = new pg.Client(conString);
pg_client.connect();

var Account = module.exports = function ()
{
	this.id = null;
}

Account.prototype.login = function (token, callback)
{
	var self = this;

	if ( typeof token.id == 'undefined' || typeof token.timestamp == 'undefined' || typeof token.hash == 'undefined' ) {
		callback('bad token format', null);
		return;
	}

	pg_client.query({
		name  :'select api key',
		text  :"SELECT password FROM users WHERE id = $1",
		values:[token.id]
	}, function (err, result)
	{
		if ( result.rows.length == 0 ) {
			callback('authentication failed', null);
		} else {
			shasum = crypto.createHash('sha1');
			shasum.update(result.rows[0].password + token.timestamp);

			if ( shasum.digest('hex') != token.hash ) {
				callback('authentication failed', null);
				return;
			}

			self.id = token.id;

			callback();
		}
	});
}