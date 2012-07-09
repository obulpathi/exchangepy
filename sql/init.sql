TRUNCATE symbols CASCADE;
TRUNCATE users CASCADE;
TRUNCATE matched CASCADE;
TRUNCATE orders_limit CASCADE;
TRUNCATE balances CASCADE;

INSERT INTO symbols VALUES ( 1 , 'BTC', 'BTC', TRUE, FALSE, 1, 1, 1, NULL);
INSERT INTO symbols VALUES ( 2 , 'USD', 'USD', TRUE, FALSE, 6.1, 6.2, 6.1, now());
INSERT INTO symbols VALUES ( 3 , 'EUR', 'EUR', TRUE, FALSE, 5.1, 5.2, 5.1, now());
INSERT INTO symbols VALUES ( 4 , 'GBP', 'GBP', TRUE, FALSE, 4.2, 4.3, 4.25, now());
INSERT INTO symbols VALUES ( 5 , 'XAU', 'XAU', FALSE, TRUE, 270.49, 271.49, 270.9, now());

INSERT INTO users VALUES (1, 'vorandrew@gmail.com', 'qweqwe', '13:28:51.896484', 1);
INSERT INTO users VALUES (2, 'voran333@mail.ru', 'qweqwe', '13:30:56.971909', 2);
INSERT INTO users VALUES (3, 'ninja@mail.ru', 'qweqwe', '13:30:56.971909', 2);

UPDATE balances SET balance = 100;

INSERT INTO orders_limit VALUES ( nextval('orders_id_seq'::regclass), 3, 2, NOW(), false, 5.2000, 70.0000, 70.0000,'active');


INSERT INTO orders_limit VALUES ( nextval('orders_id_seq'::regclass), 2, 1, NOW(), true, 5.0000,318.0000, 318.0000,'active');
INSERT INTO orders_limit VALUES ( nextval('orders_id_seq'::regclass), 2, 2, NOW(), false, 5.0000,318.0000, 318.0000,'active');

