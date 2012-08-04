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

		if (!isset($json[0]) || $json[0]->category != 'receive') return false;

		$tx['amount']  = $json[0]->amount;
		$tx['tx_id']   = $json[0]->txid;
		$tx['address'] = $json[0]->address;

		return $tx;
	}

	// Go

	$i                     = 0;
	$n_already_imported_tx = 0;
	$exit_now              = false;

	do {
		$trans = `bitcoind listtransactions "*" 1 $i`;

		$parsed = trans_parse_json($trans);

		if ($parsed) {

			$prepared_btc_deposit->bindParam(':tx_id', $parsed['tx_id'], PDO::PARAM_STR, 64);
			$prepared_btc_deposit->bindParam(':address', $parsed['address'], PDO::PARAM_STR, 52);
			$prepared_btc_deposit->bindParam(':amount', $parsed['amount'], PDO::PARAM_STR, 52);

			$prepared_btc_deposit->execute();

			$res = $prepared_btc_deposit->fetch();

			switch ($res[0]) {
				case 'unknown address':
					throw new Exception(date('Y-m-d h:i:s') . " Unknown address in bitcoind");
					break;
				case 'transaction exits':
					$n_already_imported_tx++;
					break;
			}
		} else {
			$exit_now = true;
		}

		$i++;

	} while ($n_already_imported_tx < 10 && $exit_now == false);
