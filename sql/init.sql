TRUNCATE symbols CASCADE;
TRUNCATE users CASCADE;
TRUNCATE matched CASCADE;
TRUNCATE orders_limit CASCADE;
TRUNCATE balances CASCADE;
TRUNCATE users CASCADE;
TRUNCATE fees CASCADE;

INSERT INTO symbols VALUES (1, 'USD', 'USD', 1.000000, 1.000000, 0.000000, NULL, 1, 0, 10.00);
INSERT INTO symbols VALUES (2, 'BTC', 'BTC', 11.000000, 11.500000, 0.000000, NULL, 2, 2, 1.00);
INSERT INTO symbols VALUES (3, 'EUR', 'EUR', 1.312800, 1.312900, 0.000000, NULL, 1, 0, 10.00);
INSERT INTO symbols VALUES (4, 'CHF', 'CHF', 1.078399, 1.078865, 0.000000, NULL, 1, 0, 10.00);
INSERT INTO symbols VALUES (5, 'ILS', 'ILS', 0.255840, 0.256230, 0.000000, NULL, 1, 0, 40.00);
INSERT INTO symbols VALUES (6, 'SPY', 'SPY', 146.960000, 147.020000, 147.240000, NOW(), 8, 2, 0.10);
INSERT INTO symbols VALUES (7, 'GLD', 'GLD', 171.800000, 171.900000, 171.800000, NOW(), 8, 2, 0.10);
INSERT INTO symbols VALUES (8, 'SLV', 'SLV', 33.600000, 33.700000, 33.600000, NULL, 8, 2, 0.10);

INSERT INTO users VALUES (1, 'vorandrew@gmail.com', 'qweqwe', '13:28:51.896484', 1);
INSERT INTO users VALUES (2, 'voran333@mail.ru', 'qweqwe', '13:30:56.971909', 2);
INSERT INTO users VALUES (3, 'ninja@mail.ru', 'qweqwe', '13:30:56.971909', 3);

UPDATE balances SET balance = 100;

INSERT INTO orders_limit VALUES ( nextval('orders_id_seq'::regclass), 3, 2, NOW(), NOW() + INTERVAL '1 day', false,
5.2000, 70.0000, 70.0000,'active', 'gtc');


INSERT INTO orders_limit VALUES ( nextval('orders_id_seq'::regclass), 2, 1, NOW(), NOW() + INTERVAL '1 day', true,
5.0000,
318.0000,
318.0000,'active', 'gtc');

INSERT INTO orders_limit VALUES ( nextval('orders_id_seq'::regclass), 2, 2, NOW(), NOW() + INTERVAL '1 day', false,
5.0000,318.0000, 318.0000,
'active','gtc');

INSERT INTO orders_limit VALUES ( nextval('orders_id_seq'::regclass), 2, 2, NOW(), NOW() + INTERVAL '1 day', false,
5.0000,318.0000, 318.0000,
'active','iok');

