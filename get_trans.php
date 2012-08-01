<?php

	// Checking if we are alone

	$instances_running = `ps auxx | grep get_trans | grep -v grep | wc -l`;

	if ((int)$instances_running > 1)
		exit;

	// Bootstrap DB

	$dbname   = 'exchange';
	$host     = 'localhost';
	$username = 'exchange';
	$password = 'qweqwe';

	try {
		$dbh = new PDO("pgsql:dbname=$dbname;host=$host", $username, $password);
	} catch (Exception $e) {
		throw new Exception(date('Y-m-d h:i:s') . " DB connect fail");
	}

	$prepared_btc_deposit = $dbh->prepare("SELECT btc_deposit(:tx_id,:address,:amount)");

	// JSON parsing of output

	function trans_parse_json($json_data)
	{

		if (!$json_data) {
			throw new Exception(date('Y-m-d h:i:s') . " No response from bitcoind");
		}

		try {
			$json = json_decode($json_data);
		} catch (Exception $e) {
			throw new Exception(date('Y-m-d h:i:s') . " JSON parsing failed - check bitcoind");
		}

//		$tx['amount']  = $json['amount'];
//		$tx['tx_id']   = $json['tx_id'];
//		$tx['address'] = $json['address'];

		$tx['amount']  = rand(0, 1000) / 100;
		$tx['tx_id']   = rand(0, 100000);
		$tx['address'] = '1QGTBN8pkxCT4iNUScxe9SXNELFyT15s2o';

		return $tx;
	}

	// Go

	$i = 0;

	do {
		$trans = `bitcoind listtransactions "*" 1 $i`;

		$parsed = trans_parse_json($trans);

		$prepared_btc_deposit->bindParam(':tx_id', $parsed['tx_id'], PDO::PARAM_STR, 52);
		$prepared_btc_deposit->bindParam(':address', $parsed['address'], PDO::PARAM_STR, 52);
		$prepared_btc_deposit->bindParam(':amount', $parsed['amount'], PDO::PARAM_STR, 52);

		$prepared_btc_deposit->execute();

		$i++;
	} while ($i < 30);
