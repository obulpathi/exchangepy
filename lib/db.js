var db = null, pg = require('pg'), config = require('./../config.js');

exports.db = function ()
{
	if ( db === null ) {
		var conString = "tcp://" + config.pg.username + ":" + config.pg.password + "@" + config.pg.host + "/" + config.pg.db;
		db = new pg.Client(conString);
		db.connect();
	}
	return db;
}