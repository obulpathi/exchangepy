<?php

	// Checking if we are alone

	$instances_running = `ps auxx | grep conf_trans | grep -v grep | wc -l`;

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

	// Preparing statements

	$prepared_btc_deposit_conf = $dbh->prepare("
					UPDATE
						transfers_btc
					SET
						conf = :conf
					WHERE
						trans = :tx_id");

	$prepared_get_trans = $dbh->prepare("SELECT
						trans
					FROM
						transfers as t
						LEFT JOIN transfers_btc as b ON t.id = b.id
					WHERE
						t.status = 'progress'
						AND b.conf < 6");

	// Talking to bitcoind

	function get_confirmations($txid)
	{
		$trans = `bitcoind gettransaction $txid`;

		if (!$trans) {
			throw new Exception(date('Y-m-d h:i:s') . " No response from bitcoind");
		}

		try {
			$json = json_decode($trans);
		} catch (Exception $e) {
			throw new Exception(date('Y-m-d h:i:s') . " JSON parsing failed - check bitcoind");
		}

		if (!isset($json->confirmations)) {
			throw new Exception(date('Y-m-d h:i:s') . " JSON parsing failed - wrong format");
		}

		return (int)$json->confirmations;
	}

	// Getting unconfirmed transactions

	$prepared_get_trans->execute();

	$transactions = $prepared_get_trans->fetchAll();

	foreach ($transactions as $one) {

		$confirmations = get_confirmations($one[0]);

		$prepared_btc_deposit_conf->bindParam(':tx_id', $one[0], PDO::PARAM_STR, 64);
		$prepared_btc_deposit_conf->bindParam(':conf', $confirmations, PDO::PARAM_INT);

		$res = $prepared_btc_deposit_conf->execute();

		if ($res == false) {
			throw new Exception(date('Y-m-d h:i:s') . " Failed btc_deposit_conf - " . $one[0] . " - conf:" . $confirmations);
		}

		$prepared_btc_deposit_conf->errorInfo();
	}