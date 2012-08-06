var assert = require("assert");
var Account = require('../lib/account.js');

describe('Account', function ()
{
	describe('Login', function ()
	{
		var account = new Account();

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
	})
})