--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

ALTER TABLE ONLY public.users DROP CONSTRAINT users_currency_fkey;
ALTER TABLE ONLY public.orders_stop DROP CONSTRAINT orders_stop_users_fkey;
ALTER TABLE ONLY public.orders_stop DROP CONSTRAINT orders_stop_symbol_fkey;
ALTER TABLE ONLY public.orders_limit DROP CONSTRAINT orders_limit_users_fkey;
ALTER TABLE ONLY public.orders_limit DROP CONSTRAINT orders_limit_symbol_fkey;
ALTER TABLE ONLY public.matched DROP CONSTRAINT matched_sell_fkey;
ALTER TABLE ONLY public.matched DROP CONSTRAINT matched_buy_fkey;
ALTER TABLE ONLY public.balances DROP CONSTRAINT balances_user_fkey;
ALTER TABLE ONLY public.balances DROP CONSTRAINT balances_symbol_fkey;
DROP TRIGGER t_upd_stopout ON public.symbols;
DROP TRIGGER t_new_order ON public.orders_limit;
DROP TRIGGER t_fee_balance ON public.fees;
DROP TRIGGER t_balance ON public.users;
DROP INDEX public.i_users2;
DROP INDEX public.i_users;
DROP INDEX public.i_ol_dt;
ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
ALTER TABLE ONLY public.users DROP CONSTRAINT users_email_key;
ALTER TABLE ONLY public.symbols DROP CONSTRAINT symbols_symbol_key;
ALTER TABLE ONLY public.symbols DROP CONSTRAINT symbols_pkey;
ALTER TABLE ONLY public.orders_stop DROP CONSTRAINT orders_stop_pkey;
ALTER TABLE ONLY public.orders_limit DROP CONSTRAINT orders_id_key;
ALTER TABLE ONLY public.matched DROP CONSTRAINT matched_buy_sell_key;
ALTER TABLE ONLY public.fees DROP CONSTRAINT fees_pkey;
ALTER TABLE ONLY public.balances DROP CONSTRAINT balances_user_symbol_key;
ALTER TABLE public.users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.symbols ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.orders_stop ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.orders_limit ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.fees ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE public.users_id_seq;
DROP TABLE public.users;
DROP SEQUENCE public.symbols_id_seq;
DROP TABLE public.symbols;
DROP SEQUENCE public.orders_stop_id_seq;
DROP TABLE public.orders_stop;
DROP SEQUENCE public.orders_id_seq;
DROP TABLE public.orders_limit;
DROP TABLE public.matched;
DROP SEQUENCE public.fees_id_seq;
DROP TABLE public.fees;
DROP TABLE public.balances;
DROP FUNCTION public.t_stopout();
DROP FUNCTION public.t_order_match();
DROP FUNCTION public.t_fee_bal();
DROP FUNCTION public.t_balance_acc();
DROP FUNCTION public.symbol_update_bidask(v_symbol integer);
DROP FUNCTION public.punish(v_order_id integer, v_amount numeric);
DROP FUNCTION public.buying_power(v_users integer);
DROP PROCEDURAL LANGUAGE plpgsql;
DROP SCHEMA public;
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: exchange
--

CREATE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO exchange;

SET search_path = public, pg_catalog;

--
-- Name: buying_power(integer); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION buying_power(v_users integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$BEGIN
RETURN 	2 * SUM( CASE
		WHEN b.balance > 0 AND s.bid = 0 THEN
			0
		WHEN b.balance > 0 AND s.bid < 1 THEN
			b.balance * s.bid
		WHEN b.balance > 0 AND s.bid >= 1 THEN
			b.balance / s.bid
		WHEN b.balance < 0 AND s.ask = 0 THEN
			b.balance * 999999999
		WHEN b.balance < 0 AND s.ask < 1 THEN
			b.balance * s.ask
		WHEN b.balance < 0 AND s.ask >= 1 THEN
			b.balance / s.ask
	END ) as power
FROM
	balances as b
	LEFT JOIN symbols as s ON b.symbol = s.id
WHERE
	users = v_users
	AND balance != 0;
END;$$;


ALTER FUNCTION public.buying_power(v_users integer) OWNER TO exchange;

--
-- Name: punish(integer, numeric); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION punish(v_order_id integer, v_amount numeric) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE
		orders_limit
	SET
		status = 'fail'
	WHERE
		id = v_order_id;

	INSERT INTO
		fees(id, dt, users, order_id, amount, fee_type )
	SELECT
		nextval('fees_id_seq'::regclass),
		now(),
		users,
		id,
		v_amount * 0.01,
		'fail'
	FROM
		orders_limit
	WHERE
		id = v_order_id;
END;
$$;


ALTER FUNCTION public.punish(v_order_id integer, v_amount numeric) OWNER TO exchange;

--
-- Name: FUNCTION punish(v_order_id integer, v_amount numeric); Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON FUNCTION punish(v_order_id integer, v_amount numeric) IS 'Punishment for non-performance of orders';


--
-- Name: symbol_update_bidask(integer); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION symbol_update_bidask(v_symbol integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
        v_bid   numeric(8,4);
        v_ask   numeric(8,4);
BEGIN

        SELECT
                price
        INTO
                v_bid
        FROM
                orders_limit
        WHERE
                symbol = v_symbol
                AND buy_sell = TRUE
                AND status = 'active'
                AND unfilled > 0
        ORDER BY
                price DESC
        LIMIT 1;

        SELECT
                price
        INTO
                v_ask
        FROM
                orders_limit
        WHERE
                symbol = v_symbol
                AND buy_sell = FALSE
                AND status = 'active'
                AND unfilled > 0
        ORDER BY
                price DESC
        LIMIT 1;

        UPDATE
                symbols
        SET
                bid = COALESCE(v_bid, 0),
                ask = COALESCE(v_ask, 0)
        WHERE
                id = v_symbol;
END;$$;


ALTER FUNCTION public.symbol_update_bidask(v_symbol integer) OWNER TO exchange;

--
-- Name: t_balance_acc(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_balance_acc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	INSERT INTO
		balances (users, symbol, balance)
	SELECT
		NEW.id, id,0
	FROM
		symbols
	WHERE
		is_currency = TRUE;

	RETURN NEW;
END
$$;


ALTER FUNCTION public.t_balance_acc() OWNER TO exchange;

--
-- Name: t_fee_bal(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_fee_bal() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE
		balances
	SET
		balance = balance - NEW.amount
	WHERE
		users = NEW.users
		AND symbol = 1;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.t_fee_bal() OWNER TO exchange;

--
-- Name: t_order_match(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_order_match() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	c_orders	refcursor;
	v_order		record;
	v_unfilled	numeric(8,4);
	v_effective	numeric(12,2);
	v_bp_my		numeric(12,2);
	v_bp_his	numeric(12,2);
BEGIN

	IF NEW.buy_sell = TRUE THEN
		OPEN c_orders FOR SELECT
			*
		FROM
			orders_limit as o
		WHERE
			o.buy_sell = false
			AND o.symbol = NEW.symbol
			AND o.status = 'active'
			AND o.exp_dt >= NOW()
			AND o.unfilled > 0
			AND o.price <= NEW.price
			AND o.users != NEW.users
		ORDER BY
			o.price ASC;
	ELSE
		OPEN c_orders FOR SELECT
			*
		FROM
			orders_limit as o
		WHERE
			o.buy_sell = true
			AND o.symbol = NEW.symbol
			AND o.status = 'active'
			AND o.exp_dt >= NOW()
			AND o.unfilled > 0
			AND o.price >= NEW.price
			AND o.users != NEW.users
		ORDER BY
			o.price DESC;

	END IF;

	v_unfilled = NEW.unfilled;

	LOOP
		FETCH c_orders INTO v_order;

		-- If not found match

		IF NOT FOUND THEN
			EXIT;
		END IF;

		-- Getting effective matched volume

		v_bp_his	= buying_power(v_order.users);

		IF v_bp_his <= 0 THEN
			PERFORM punish( v_order.id, v_order.unfilled );
			CONTINUE;
		END IF;

		IF v_bp_his >= v_order.unfilled THEN
			v_effective = v_order.unfilled;
		ELSE
			v_effective = v_bp_his;
			PERFORM punish( v_order.id, v_order.unfilled - v_bp_his );
		END IF;

		v_bp_my	= buying_power(NEW.users);

		IF v_bp_my <= 0 THEN
			PERFORM punish( NEW.id, NEW.unfilled );
			EXIT;
		END IF;

		IF v_bp_my < v_effective * 1.003 THEN
			v_effective = v_bp_my;
			PERFORM punish( NEW.id, NEW.unfilled - v_bp_my );
		END IF;

		-- Updating balances + orders

		-- Updating my BTC balance

		UPDATE
			balances
		SET
			balance = CASE
				WHEN NEW.buy_sell = TRUE THEN
					balance + v_effective
				ELSE
					balance - v_effective * 1.003
				END
		WHERE
			users = NEW.users
			AND symbol = 1;

		-- Updating my fiat balance

		UPDATE
			balances
		SET
			balance = CASE
				WHEN NEW.buy_sell = TRUE THEN
					balance - v_order.price * v_effective * 1.003
				ELSE
					balance + v_order.price * v_effective
				END
		WHERE
			users = NEW.users
			AND symbol = NEW.symbol;

		-- Updating his BTC balance

		UPDATE
			balances
		SET
			balance = CASE
				WHEN NEW.buy_sell = TRUE THEN
					balance - v_effective
				ELSE
					balance + v_effective * 1.003
				END
		WHERE
			users = v_order.users
			AND symbol = 1;

		-- Updating his fiat balance

		UPDATE
			balances
		SET
			balance = CASE
				WHEN NEW.buy_sell = TRUE THEN
					balance + v_order.price * v_effective
				ELSE
					balance - v_order.price * v_effective * 1.003
				END
		WHERE
			users = v_order.users
			AND symbol = NEW.symbol;

		-- Updating orders

		UPDATE
			orders_limit
		SET
			unfilled = unfilled - v_effective,
			status = CASE
					WHEN unfilled - v_effective = 0 THEN
						'filled'
					ELSE
						status
				END
		WHERE
			id = NEW.id OR id = v_order.id;

		-- Inserting match

		IF NEW.buy_sell = TRUE THEN
			INSERT INTO matched (buy, sell, amount ) VALUES ( NEW.id, v_order.id, v_effective );
		ELSE
			INSERT INTO matched (buy, sell, amount ) VALUES ( v_order.id, NEW.id, v_effective );
		END IF;

		-- Updating last trade for symbol

		UPDATE
			symbols
		SET
			last_price = v_order.price,
			last_dt = now(),
			bid	= CASE
					WHEN NEW.buy_sell = FALSE THEN v_order.price
					ELSE bid
				END,
			ask	= CASE
					WHEN NEW.buy_sell = TRUE THEN v_order.price
					ELSE ask
				END
		WHERE
			id = NEW.symbol;

		-- Updating unfilled amount

		v_unfilled = v_unfilled - v_effective;

		EXIT WHEN v_unfilled = 0 OR v_bp_my < v_effective;

	END LOOP;

	CLOSE c_orders;

	IF NEW.types = 'iok' AND v_unfilled > 0 THEN
		UPDATE
			orders_limit
		SET
			status = 'filled'
		WHERE
			id = NEW.id;
	END IF;

	PERFORM symbol_update_bidask(NEW.symbol);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.t_order_match() OWNER TO exchange;

--
-- Name: t_stopout(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_stopout() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	c_users	refcursor;
	v_user	record;
	v_bp	numeric(12,2);
BEGIN

	-- If not connected to bid/ask change

	IF NEW.bid = OLD.bid AND NEW.ask = OLD.ask THEN
		RETURN NEW;
	END IF;

	-- Get pretenders

	OPEN c_users FOR SELECT
		users
	FROM
		balances
	WHERE
		balance < 0
		AND symbol = NEW.id;

	LOOP
		FETCH c_users INTO v_user;

		-- No more

		IF NOT FOUND THEN
			EXIT;
		END IF;

		-- Getting 90% buying power for debit balances

		SELECT SUM( CASE
				WHEN b.balance > 0 AND s.bid = 0 THEN
					0
				WHEN b.balance > 0 AND s.bid < 1 THEN
					b.balance * s.bid * 0.9
				WHEN b.balance > 0 AND s.bid >= 1 THEN
					b.balance / s.bid * 0.9
				WHEN b.balance < 0 AND s.ask = 0 THEN
					b.balance * 999
				WHEN b.balance < 0 AND s.ask < 1 THEN
					b.balance * s.ask
				WHEN b.balance < 0 AND s.ask >= 1 THEN
					b.balance / s.ask
			END ) as power
		INTO
			v_bp
		FROM
			balances as b
			LEFT JOIN symbols as s ON b.symbol = s.id
		WHERE
			users = v_user.users
			AND balance != 0;

		-- Justice

		INSERT INTO
			orders_limit
		SELECT
			nextval('orders_id_seq'::regclass),
			2,
			b.users,
			NOW(),
			NOW() + INTERVAL '365 day',
			CASE WHEN b.balance > 0 THEN FALSE ELSE TRUE END as buy_sell,
			CASE WHEN b.balance > 0 THEN 0.0001 ELSE 999 END as price,
			@b.balance,
			@b.balance,
			'active',
			'gtc'
		FROM
			balances as b
		WHERE
			v_bp <= 0
			AND b.users = v_user.users
			AND b.symbol = 1;
	END LOOP;

	CLOSE c_users;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.t_stopout() OWNER TO exchange;

--
-- Name: FUNCTION t_stopout(); Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON FUNCTION t_stopout() IS 'Stop out';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: balances; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE balances (
    users integer NOT NULL,
    symbol smallint NOT NULL,
    balance numeric(10,4) NOT NULL
);


ALTER TABLE public.balances OWNER TO exchange;

--
-- Name: TABLE balances; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE balances IS 'balances';


--
-- Name: fees; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE fees (
    id integer NOT NULL,
    dt timestamp without time zone NOT NULL,
    users integer NOT NULL,
    amount numeric(6,3) NOT NULL,
    fee_type character varying(10) NOT NULL,
    order_id integer,
    descr text
);


ALTER TABLE public.fees OWNER TO exchange;

--
-- Name: TABLE fees; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE fees IS 'Misc fees';


--
-- Name: fees_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE fees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.fees_id_seq OWNER TO exchange;

--
-- Name: fees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE fees_id_seq OWNED BY fees.id;


--
-- Name: matched; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE matched (
    buy integer NOT NULL,
    sell integer NOT NULL,
    amount numeric(8,4) NOT NULL
);


ALTER TABLE public.matched OWNER TO exchange;

--
-- Name: TABLE matched; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE matched IS 'matched orders';


--
-- Name: orders_limit; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE orders_limit (
    id integer NOT NULL,
    symbol smallint NOT NULL,
    users integer NOT NULL,
    dt timestamp without time zone NOT NULL,
    exp_dt timestamp without time zone,
    buy_sell boolean NOT NULL,
    price numeric(8,4) NOT NULL,
    amount numeric(8,2) NOT NULL,
    unfilled numeric(8,2) NOT NULL,
    status character varying(10) NOT NULL,
    types character varying(10) NOT NULL
);


ALTER TABLE public.orders_limit OWNER TO exchange;

--
-- Name: TABLE orders_limit; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE orders_limit IS 'limit orders';


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.orders_id_seq OWNER TO exchange;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE orders_id_seq OWNED BY orders_limit.id;


--
-- Name: orders_stop; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE orders_stop (
    id integer NOT NULL,
    symbol smallint NOT NULL,
    users integer NOT NULL,
    dt timestamp without time zone NOT NULL,
    buy_sell boolean NOT NULL,
    price numeric(7,4) NOT NULL,
    amount numeric(8,2) NOT NULL,
    type character varying(10) NOT NULL
);


ALTER TABLE public.orders_stop OWNER TO exchange;

--
-- Name: TABLE orders_stop; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE orders_stop IS 'stop orders - sl, tp, stop outs';


--
-- Name: orders_stop_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE orders_stop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.orders_stop_id_seq OWNER TO exchange;

--
-- Name: orders_stop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE orders_stop_id_seq OWNED BY orders_stop.id;


--
-- Name: symbols; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE symbols (
    id smallint NOT NULL,
    symbol character(3) NOT NULL,
    descr character varying NOT NULL,
    is_currency boolean NOT NULL,
    reversed boolean NOT NULL,
    bid numeric(8,4) NOT NULL,
    ask numeric(8,4) NOT NULL,
    last_price numeric(8,4) NOT NULL,
    last_dt timestamp without time zone
);


ALTER TABLE public.symbols OWNER TO exchange;

--
-- Name: TABLE symbols; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE symbols IS 'symbols for trade ';


--
-- Name: symbols_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE symbols_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.symbols_id_seq OWNER TO exchange;

--
-- Name: symbols_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE symbols_id_seq OWNED BY symbols.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    email character varying(150) NOT NULL,
    password character varying(52) NOT NULL,
    dt time without time zone NOT NULL,
    currency smallint NOT NULL
);


ALTER TABLE public.users OWNER TO exchange;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE users IS 'user accounts';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO exchange;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY fees ALTER COLUMN id SET DEFAULT nextval('fees_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_limit ALTER COLUMN id SET DEFAULT nextval('orders_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_stop ALTER COLUMN id SET DEFAULT nextval('orders_stop_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY symbols ALTER COLUMN id SET DEFAULT nextval('symbols_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: balances_user_symbol_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY balances
    ADD CONSTRAINT balances_user_symbol_key UNIQUE (users, symbol);


--
-- Name: fees_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY fees
    ADD CONSTRAINT fees_pkey PRIMARY KEY (id);


--
-- Name: matched_buy_sell_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY matched
    ADD CONSTRAINT matched_buy_sell_key UNIQUE (buy, sell);


--
-- Name: orders_id_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY orders_limit
    ADD CONSTRAINT orders_id_key UNIQUE (id);


--
-- Name: orders_stop_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY orders_stop
    ADD CONSTRAINT orders_stop_pkey PRIMARY KEY (id);


--
-- Name: symbols_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY symbols
    ADD CONSTRAINT symbols_pkey PRIMARY KEY (id);


--
-- Name: symbols_symbol_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY symbols
    ADD CONSTRAINT symbols_symbol_key UNIQUE (symbol);


--
-- Name: users_email_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: i_ol_dt; Type: INDEX; Schema: public; Owner: exchange; Tablespace: 
--

CREATE INDEX i_ol_dt ON orders_limit USING btree (dt);


--
-- Name: i_users; Type: INDEX; Schema: public; Owner: exchange; Tablespace: 
--

CREATE INDEX i_users ON orders_limit USING btree (users);


--
-- Name: i_users2; Type: INDEX; Schema: public; Owner: exchange; Tablespace: 
--

CREATE INDEX i_users2 ON orders_stop USING btree (users);


--
-- Name: t_balance; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_balance
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE PROCEDURE t_balance_acc();


--
-- Name: t_fee_balance; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_fee_balance
    AFTER INSERT ON fees
    FOR EACH ROW
    EXECUTE PROCEDURE t_fee_bal();


--
-- Name: t_new_order; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_new_order
    AFTER INSERT ON orders_limit
    FOR EACH ROW
    EXECUTE PROCEDURE t_order_match();


--
-- Name: t_upd_stopout; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_upd_stopout
    AFTER UPDATE ON symbols
    FOR EACH ROW
    EXECUTE PROCEDURE t_stopout();


--
-- Name: balances_symbol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY balances
    ADD CONSTRAINT balances_symbol_fkey FOREIGN KEY (symbol) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: balances_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY balances
    ADD CONSTRAINT balances_user_fkey FOREIGN KEY (users) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matched_buy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY matched
    ADD CONSTRAINT matched_buy_fkey FOREIGN KEY (buy) REFERENCES orders_limit(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matched_sell_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY matched
    ADD CONSTRAINT matched_sell_fkey FOREIGN KEY (sell) REFERENCES orders_limit(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: orders_limit_symbol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_limit
    ADD CONSTRAINT orders_limit_symbol_fkey FOREIGN KEY (symbol) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: orders_limit_users_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_limit
    ADD CONSTRAINT orders_limit_users_fkey FOREIGN KEY (users) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: orders_stop_symbol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_stop
    ADD CONSTRAINT orders_stop_symbol_fkey FOREIGN KEY (symbol) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: orders_stop_users_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_stop
    ADD CONSTRAINT orders_stop_users_fkey FOREIGN KEY (users) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: users_currency_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_currency_fkey FOREIGN KEY (currency) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--
