var crypto = require('crypto'), db = require('./db').db(), Step = require('step');

var Account = module.exports = function ()
{
	this.id = null;
	this.api_key = null;
}

Account.prototype.login = function (token, callback)
{
	var self = this;

	if ( typeof token.id == 'undefined' || typeof token.timestamp == 'undefined' || typeof token.hash == 'undefined' ) {
		callback('bad token format');
		return;
	}

	db.query({
		name   : 'select api key',
		text   : "SELECT password FROM users WHERE id = $1",
		values : [token.id]
	}, function (err, result)
	{
		if ( result.rows.length == 0 ) {
			callback('authentication failed', null);
		} else {
			self.api_key = result.rows[0].password;

			var shasum = crypto.createHash('sha1');
			shasum.update(self.api_key + token.timestamp);

			if ( shasum.digest('hex') != token.hash ) {
				callback('authentication failed', null);
				return;
			}

			self.id = token.id;

			callback(null);
		}
	});
}

Account.prototype.cmd = function (data, callback)
{
	var str_payload = JSON.stringify(data.payload);
	var shasum = crypto.createHash('sha1');

	shasum.update(this.api_key + data.timestamp + str_payload);

	if ( data.hash != shasum.digest('hex') ) {
		callback('hash does not match');
		return;
	}

	callback();
}

Account.prototype.new_order = function (data, callback)
{

// Check types

	var order_types = [
		'gtc'
		, 'iok'
//		, 'fok'  // Soon
	];

	if ( typeof data.type == 'undefined' || order_types.indexOf(data.type.toLowerCase()) === -1 ) {
		callback('missing/incorrect order type');
		return;
	}

// Check symbol

	var symbols = new Array();

	symbols[2] = 'btcusd';
	symbols[3] = 'btceur';
	symbols[4] = 'btcgbp';

	//symbols[5] = 'xaubtc';

	if ( typeof data.symbol == 'undefined' || symbols.indexOf(data.symbol.toLowerCase()) === -1 ) {
		callback('missing/incorrect symbol');
		return;
	}

// Check symbol

	if ( typeof data.buy_sell == 'undefined' || ( data.buy_sell !== true && data.buy_sell !== false) ) {
		callback('missing/incorrect buy/sell');
		return;
	}

// Check price

	if ( typeof data.price != 'number' || data.price <= 0 || data.price >= 99999 ) {
		callback('missing/incorrect price');
		return;
	}

// Check expire

	if ( typeof data.expire != 'undefined' ) {
		try {
			var expire = new Date(data.expire);
		} catch ( e ) {
			callback('missing/incorrect expire date');
			return;
		}

		if ( new Date(data.expire) <= new Date() ) {
			callback('missing/incorrect expire date');
			return;
		}

	} else {
		var expire = new Date();
		expire.setDate(expire.getDate() + 365);
	}

// Check amount

	if ( typeof data.amount != 'number' || data.amount <= 0 || data.amount > 21000000 ) {
		callback('missing/incorrect amount');
		return;
	}

// Checks finished

	var arr_order = [
		symbols.indexOf(data.symbol.toLowerCase()), this.id, expire, data.buy_sell, data.price, data.amount,
		data.amount, 'active', data.type.toLowerCase()
	];

	db.query({
		name   : 'Placing order',
		text   : "SELECT new_order( $1,$2,NOW(),$3 ,$4,$5,$6,$7,$8,$9)",
		values : arr_order
	}, function (err, result)
	{
		if ( err ) {
			callback(err);
			return;
		}

		callback(null, result.rows[0].id);
	});

}

Account.prototype.generateNewAddress = function (callback)
{
	var self = this;

	Step(function ()
	{
		db.query({
			name   : 'Getting quantity of BTC addresses',
			text   : "SELECT COUNT(*) as total FROM users_btc WHERE users = $1",
			values : [self.id]
		}, this.parallel());

		db.query({
			name   : 'Getting buying power',
			text   : "SELECT buying_power($1) as btc",
			values : [self.id]
		}, this.parallel());
	}, function (err, btc_qua, buying_power)
	{
		if ( err ) {
			callback(err);
			return;
		}

		var btc_qua = btc_qua.rows[0].total;
		var btc = buying_power.rows[0].btc;

		if ( btc_qua == 0 ) {

			// if it is the first address
			get_btc_address(self.id, 0, callback);

		} else if ( btc > 0.05 ) {

			// if he has enough BTC

			get_btc_address(self.id, btc_qua, function (err, address)
			{
				if ( err ) {
					callback(err);
					return;
				}

				db.query({
					name   : 'Taking  fee for new BTC address',
					text   : "SELECT fee( $1, 'new address', 0.05, 0)",
					values : [self.id]
				}, function (err)
				{
					if ( err ) {
						callback(err);
						return;
					}
					callback(null, address);
				});
			});
		} else {
			callback("you don't have enough BTC");
		}
	});

	var get_btc_address = function (user_id, qua, callback)
	{
		var spawn = require('child_process').spawn;
		var genaddr = spawn('python', [ 'addrgen.py', user_id , qua + 1]);

		var cmd_out;

		genaddr.stdout.on('data', function (data)
		{
			cmd_out = JSON.parse(data);
		});

		genaddr.on('exit', function (code)
		{
			if ( code == 0 ) {

				db.query({
					name   : 'Inserting new BTC address',
					text   : "INSERT INTO users_btc( address, users) VALUES ($1, $2)",
					values : [cmd_out.addr, user_id]
				}, function (err)
				{
					if ( err ) {
						callback(err);
						return;
					}

					callback(null, cmd_out.addr);
				});
			} else {
				callback('address generation failed');
			}
		});
	};
}

Account.prototype.issueCode = function (symbol, amount, callback)
{
	var self = this;

	var shasum = crypto.createHash('sha1');

	crypto.randomBytes(64, function (err, buf)
	{
		if ( err ) {
			callback(err);
			return;
		}

		shasum.update(buf);
		var code = shasum.digest('hex');

		db.query({
			name   : 'Issuing code',
			text   : "SELECT issue_code($1, $2, $3, $4)",
			values : [self.id, symbol, amount, code]
		}, function (err, result)
		{
			if ( err ) {
				callback(err);
				return;
			}

			if ( result.rows[0].issue_code == true ) {
				callback(null, code);
			} else {
				callback('not enough funds');
			}
		});
	});
}

Account.prototype.depositCode = function (code, callback)
{
	var self = this;

	db.query({
		name   : 'Deposit code',
		text   : "SELECT deposit_code($1, $2)",
		values : [self.id, code]
	}, function (err, result)
	{
		if ( err ) {
			callback(err);
			return;
		}

		if ( result.rows[0].deposit_code == true ) {
			callback(null);
		} else {
			callback('invalid code');
		}
	});
}