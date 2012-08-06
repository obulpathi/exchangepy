var assert = require("assert");
var Account = require('../lib/account.js');

describe('Account', function ()
{
	var account = new Account();

	describe('Login', function ()
	{
		var token = {
			id        : 3,
			timestamp : 1344262673623,
			hash      : '9ad42ff5187eba83d20c16b4abae45c9b0a1afff'
		};

		it('correct', function (done)
		{
			account.login(token, done);
		});

		it('not correct', function (done)
		{
			token.hash = 'fuckedup';

			account.login(token, function (err)
			{
				if ( err ) {
					done();
					return;
				}
			});
		});
	});

	var payload = {
		symbol   : 'usd',
		expire   : new Date( new Date().getTime() + 5000000),
		buy_sell : true,
		price    : 0.05455,
		type     : 'gtc',
		amount   : 10
	};

	describe('Orders', function ()
	{
		it('gtc order', function (done)
		{
			account.new_order(payload, done);
		});

		it('stop order', function (done)
		{
			payload.type = 'stop';
			account.new_order(payload, done);
		});

	});
});
