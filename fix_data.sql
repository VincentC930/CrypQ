-- replace "file path" with actual file path
-- \i /file_path/fix_data.sql
CREATE TABLE ADDRESSES (
	address VARCHAR(42),
	eth_balance NUMERIC,
	PRIMARY KEY (address)
);

CREATE TABLE BLOCKS (
    hash VARCHAR(66) PRIMARY KEY,
    number NUMERIC,
    timestamp TIMESTAMP WITH TIME ZONE,
    extra_data VARCHAR(8192), -- 32 byte field on the blockchain
    base_fee_per_gas NUMERIC,
    size NUMERIC,
    miner VARCHAR(42)
);

CREATE TABLE WITHDRAWALS (
    hash VARCHAR(66),
    withdrawal_index NUMERIC,
    validator NUMERIC,
    address VARCHAR(42),
    amount NUMERIC,
    PRIMARY KEY (hash, withdrawal_index)
);

CREATE TABLE TRANSACTIONS (
    hash VARCHAR(66) PRIMARY KEY,
    transaction_index NUMERIC,
    value NUMERIC,
    from_address VARCHAR(42),
    to_address VARCHAR(42),
    gas NUMERIC,
    max_priority_fee_per_gas NUMERIC,
    input VARCHAR(8192),
    block_hash VARCHAR(66),
    transaction_type NUMERIC,
    nonce NUMERIC
);

CREATE TABLE TOKENS (
    address VARCHAR(42) PRIMARY KEY,
    symbol VARCHAR(20),
    name VARCHAR(100),
    decimals NUMERIC,
    total_supply NUMERIC,
    block_hash VARCHAR(66)
);

CREATE TABLE TOKEN_TRANSACTIONS (
    transaction_hash VARCHAR(66),
    log_index NUMERIC,
    token_address VARCHAR(42),
    value NUMERIC,
    PRIMARY KEY (transaction_hash, log_index)
);

CREATE TABLE CONTRACTS (
    address VARCHAR(42),
    function_sighashes VARCHAR(1024), -- 4 bytes on blockchain
    bytecode VARCHAR(8192),
    is_erc20 BOOLEAN,
    is_erc721 BOOLEAN,
    block_hash VARCHAR(66),
    PRIMARY KEY (address, block_hash)
);
-- Create unlogged tables for JSON data storage
CREATE UNLOGGED TABLE addresses_import (doc JSON);
CREATE UNLOGGED TABLE blocks_import (doc JSON);
CREATE UNLOGGED TABLE contracts_import (doc JSON);
CREATE UNLOGGED TABLE token_transactions_import (doc JSON);
CREATE UNLOGGED TABLE tokens_import (doc JSON);
CREATE UNLOGGED TABLE transactions_import (doc JSON);
CREATE UNLOGGED TABLE withdrawals_import (doc JSON);

-- Load JSON data into unlogged tables
-- replace "file path" with actual file path
-- replace "year" with slice you intend to use
\copy addresses_import FROM '/file_path/year_blocks_addresses.json';
\copy blocks_import FROM '/file_path/year_blocks_blocks.json';
\copy contracts_import FROM '/file_path/year_blocks_contracts.json';
\copy token_transactions_import FROM '/file_path/year_blocks_token_transactions.json';
\copy tokens_import FROM '/file_path/year_blocks_tokens.json';
\copy transactions_import FROM '/file_path/year_blocks_transactions.json';
\copy withdrawals_import FROM '/file_path/year_blocks_withdrawals.json';

-- Insert data into actual tables from unlogged tables
-- Addresses
INSERT INTO addresses (address, eth_balance)
SELECT (doc->>'address')::VARCHAR(42), (doc->>'eth_balance')::NUMERIC FROM addresses_import;

-- Blocks
INSERT INTO blocks (hash, number, timestamp, extra_data, base_fee_per_gas, size, miner)
SELECT (doc->>'hash')::VARCHAR(66), (doc->>'number')::NUMERIC, TO_TIMESTAMP((doc->>'timestamp'), 'YYYY-MM-DD HH24:MI:SS UTC')::TIMESTAMP WITH TIME ZONE, (doc->>'extra_data')::VARCHAR(8192), (doc->>'base_fee_per_gas')::NUMERIC, (doc->>'size')::NUMERIC, (doc->>'miner')::VARCHAR(42) FROM blocks_import;

-- Contracts
INSERT INTO contracts (address, function_sighashes, bytecode, is_erc20, is_erc721, block_hash)
SELECT (doc->>'address')::VARCHAR(42), (doc->>'function_sighashes')::VARCHAR(1024), (doc->>'bytecode')::VARCHAR(8192), (doc->>'is_erc20')::BOOLEAN, (doc->>'is_erc721')::BOOLEAN, (doc->>'block_hash')::VARCHAR(66) FROM contracts_import;

-- Transactions
INSERT INTO transactions (hash, transaction_index, value, from_address, to_address, gas, max_priority_fee_per_gas, input, block_hash, transaction_type, nonce)
SELECT (doc->>'hash')::VARCHAR(66), (doc->>'transaction_index')::NUMERIC, (doc->>'value')::NUMERIC, (doc->>'from_address')::VARCHAR(42), (doc->>'to_address')::VARCHAR(42), (doc->>'gas')::NUMERIC, (doc->>'max_priority_fee_per_gas')::NUMERIC, (doc->>'input')::VARCHAR(8192), (doc->>'block_hash')::VARCHAR(66), (doc->>'transaction_type')::NUMERIC, (doc->>'nonce')::NUMERIC FROM transactions_import;

-- Tokens
INSERT INTO tokens (address, symbol, name, decimals, total_supply, block_hash)
SELECT (doc->>'address')::VARCHAR(42), (doc->>'symbol')::VARCHAR(20), (doc->>'name')::VARCHAR(100), (doc->>'decimals')::NUMERIC, (doc->>'total_supply')::NUMERIC, (doc->>'block_hash')::VARCHAR(66) FROM tokens_import;

-- Token Transactions
INSERT INTO token_transactions (transaction_hash, log_index, token_address, value)
SELECT (doc->>'transaction_hash')::VARCHAR(66), (doc->>'log_index')::NUMERIC, (doc->>'token_address')::VARCHAR(42), (doc->>'value')::NUMERIC FROM token_transactions_import;

-- Withdrawals
INSERT INTO withdrawals (hash, withdrawal_index, validator, address, amount)
SELECT (doc->>'hash')::VARCHAR(66), (doc->>'withdrawal_index')::NUMERIC, (doc->>'validator')::NUMERIC, (doc->>'address')::VARCHAR(42), (doc->>'amount')::NUMERIC FROM withdrawals_import;

DROP TABLE addresses_import, blocks_import, contracts_import, token_transactions_import, tokens_import, transactions_import, withdrawals_import;

-- FIX ADDRESSES
CREATE TABLE TEMP_ADDRESS_JSON (
	CONTENTS JSON
);

WITH received AS (
	SELECT FROM_ADDRESS ADDRESS, SUM(VALUE) ETH
	FROM TRANSACTIONS
	GROUP BY FROM_ADDRESS
),
spent AS (
	SELECT TO_ADDRESS ADDRESS, SUM(VALUE) ETH
	FROM TRANSACTIONS
	GROUP BY TO_ADDRESS
),
missing_addresses AS (
	SELECT ADDRESS FROM (
		(SELECT FROM_ADDRESS ADDRESS FROM TRANSACTIONS
		UNION
		SELECT TO_ADDRESS ADDRESS FROM TRANSACTIONS
		UNION
		SELECT MINER ADDRESS FROM BLOCKS
		UNION
		SELECT ADDRESS FROM CONTRACTS
		UNION
		SELECT ADDRESS FROM WITHDRAWALS)
		EXCEPT
		SELECT ADDRESS FROM ADDRESSES
	)
	WHERE ADDRESS IS NOT NULL
), 
modified_address_entries AS (
	SELECT m_a.ADDRESS, GREATEST(COALESCE(r.ETH, 0) - COALESCE(S.ETH, 0), 0) ETH_BALANCE, TRUE ADJUSTED
	FROM missing_addresses m_a
	LEFT OUTER JOIN spent s
	ON m_a.address = s.address
	LEFT OUTER JOIN received r
	ON m_a.address = r.address
),
original_address_entries AS (
	SELECT ADDRESS, ETH_BALANCE, FALSE ADJUSTED 
	FROM ADDRESSES
),
combined AS (
    SELECT * FROM modified_address_entries
    UNION
    SELECT * FROM original_address_entries
)

INSERT INTO TEMP_ADDRESS_JSON
SELECT row_to_json(combined)
FROM combined;

-- write this data to
\o /file_path/adjusted_balance_year_blocks.json
SELECT * FROM TEMP_ADDRESS_JSON;
\o

CREATE TABLE TEMP_CONTRACTS_JSON (
	CONTENTS JSON
);

-- fix contracts
WITH fixed_foreign_key_contracts AS (
	SELECT *
	FROM (
		SELECT ADDRESS, IS_ERC20, IS_ERC721, NULL BLOCK_HASH
		FROM CONTRACTS
		WHERE BLOCK_HASH NOT IN (SELECT HASH FROM BLOCKS)
		UNION
		SELECT ADDRESS, IS_ERC20, IS_ERC721, BLOCK_HASH
		FROM CONTRACTS
		WHERE BLOCK_HASH IN (SELECT HASH FROM BLOCKS)
	)
),
contracts_with_versions AS (
	SELECT ADDRESS, IS_ERC20, IS_ERC721, BLOCK_HASH, ROW_NUMBER() OVER (PARTITION BY ADDRESS ORDER BY COALESCE(TIMESTAMP, '9999-12-31')) VERSION
	FROM fixed_foreign_key_contracts
	LEFT OUTER JOIN blocks
	ON fixed_foreign_key_contracts.block_hash = blocks.hash
)

INSERT INTO TEMP_CONTRACTS_JSON
SELECT row_to_json(contracts_with_versions)
FROM contracts_with_versions;

-- write this data to
\o /file_path/adjusted_contracts_year_blocks.json
SELECT * FROM TEMP_CONTRACTS_JSON;
\o

-- fix tokens
CREATE TABLE TEMP_TOKENS_JSON (
	CONTENTS JSON
);

WITH fixed_block_hash_issue AS (
	SELECT *
	FROM (
		SELECT ADDRESS, SYMBOL, NAME, DECIMALS, TOTAL_SUPPLY, NULL BLOCK_HASH, FALSE MISSING_FROM_BQ
		FROM TOKENS
		WHERE BLOCK_HASH NOT IN (SELECT HASH FROM BLOCKS)
		UNION
		SELECT ADDRESS, SYMBOL, NAME, DECIMALS, TOTAL_SUPPLY, BLOCK_HASH, FALSE MISSING_FROM_BQ
		FROM TOKENS
		WHERE BLOCK_HASH IN (SELECT HASH FROM BLOCKS)
	)
),
missing_from_bq AS (
	SELECT ADDRESS, NULL SYMBOL, NULL NAME, NULL::numeric DECIMALS, NULL::numeric TOTAL_SUPPLY, NULL BLOCK_HASH, TRUE MISSING_FROM_BQ
	FROM (
		SELECT TOKEN_ADDRESS ADDRESS FROM TOKEN_TRANSACTIONS
		EXCEPT 
		SELECT ADDRESS FROM TOKENS
	)
),
fixed_tokens AS (
	SELECT * FROM fixed_block_hash_issue
	UNION
	SELECT * FROM missing_from_bq
)


INSERT INTO TEMP_TOKENS_JSON
SELECT row_to_json(fixed_tokens)
FROM fixed_tokens;

-- write this data to
\o /file_path/adjusted_tokens_year_blocks.json
SELECT * FROM TEMP_TOKENS_JSON;
\o