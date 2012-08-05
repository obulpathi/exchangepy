TRUNCATE symbols CASCADE;
TRUNCATE users CASCADE;
TRUNCATE matched CASCADE;
TRUNCATE orders_limit CASCADE;
TRUNCATE balances CASCADE;
TRUNCATE users CASCADE;
TRUNCATE fees CASCADE;

INSERT INTO symbols VALUES (3, 'EUR', 'EUR', 0.08224, 0.08224, 0.08224, NULL, 2);
INSERT INTO symbols VALUES (2, 'USD', 'USD', 0.09524, 0.09524, 0.09524, NULL, 2);
INSERT INTO symbols VALUES (1, 'BTC', 'BTC', 1.00000, 1.00000, 1.00000, NULL, 2);
INSERT INTO symbols VALUES (4, 'XAU', 'XAU', 152.38095, 153.38095, 152.38095, NULL, 10);

INSERT INTO users VALUES (1, 'vorandrew@gmail.com', 'qweqwe', '13:28:51.896484', 1);
INSERT INTO users VALUES (2, 'voran333@mail.ru', 'qweqwe', '13:30:56.971909', 2);
INSERT INTO users VALUES (3, 'ninja@mail.ru', 'qweqwe', '13:30:56.971909', 2);

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

