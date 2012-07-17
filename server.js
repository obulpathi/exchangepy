var app = require('http').createServer(handler)
	, io = require('socket.io').listen(app)
	, path = require('path')
	, exchange = require('./lib/exchange')
	, fs = require('fs');

app.listen(8080);

function handler(request, response)
{
	var filePath = './public' + request.url;
	if (filePath == './public/')
		filePath = './public/index.html';

	path.exists(filePath, function (exists)
	{
		if (exists) {
			fs.readFile(filePath, function (error, content)
			{
				if (error) {
					response.writeHead(500);
					response.end();
				} else {
					response.writeHead(200, { 'Content-Type':'text/html' });
					response.end(content, 'utf-8');
				}
			});
		} else {
			response.writeHead(404);
			response.end();
		}
	});

}

var exch = new exchange();
exch.bind_socket_io_events(io);
exch.bind_pg_watcher();