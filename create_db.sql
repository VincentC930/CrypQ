-- replace "file path" with actual file path
-- \i /file_path/create_db.sql

CREATE TABLE ADDRESSES (
	address VARCHAR(42),
	eth_balance NUMERIC,
    adjusted BOOLEAN,
	PRIMARY KEY (address)
);

CREATE TABLE BLOCKS (
    hash VARCHAR(66) PRIMARY KEY,
    number NUMERIC,
    timestamp TIMESTAMP WITH TIME ZONE,
    extra_data VARCHAR(8192), -- 32 byte field on the blockchain
    base_fee_per_gas NUMERIC,
    size NUMERIC,
    miner VARCHAR(42) REFERENCES ADDRESSES(address)
);

CREATE TABLE WITHDRAWALS (
    hash VARCHAR(66) REFERENCES BLOCKS(hash) ,
    withdrawal_index NUMERIC,
    validator NUMERIC,
    address VARCHAR(42) REFERENCES ADDRESSES(address),
    amount NUMERIC,
    PRIMARY KEY (hash, withdrawal_index)
);

CREATE TABLE TRANSACTIONS (
    hash VARCHAR(66) PRIMARY KEY,
    transaction_index NUMERIC,
    value NUMERIC,
    from_address VARCHAR(42) REFERENCES ADDRESSES(address),
    to_address VARCHAR(42) REFERENCES ADDRESSES(address),
    gas NUMERIC,
    max_priority_fee_per_gas NUMERIC,
    input VARCHAR(8192),
    block_hash VARCHAR(66) REFERENCES BLOCKS(hash),
    transaction_type NUMERIC,
    nonce NUMERIC
);

CREATE TABLE TOKENS (
    address VARCHAR(42) PRIMARY KEY,
    symbol VARCHAR(20),
    name VARCHAR(100),
    decimals NUMERIC,
    total_supply NUMERIC,
    block_hash VARCHAR(66) REFERENCES BLOCKS(hash),
    MISSING_FROM_BQ BOOLEAN
);

CREATE TABLE TOKEN_TRANSACTIONS (
    transaction_hash VARCHAR(66) REFERENCES TRANSACTIONS(hash),
    log_index NUMERIC,
    token_address VARCHAR(42) REFERENCES TOKENS(address),
    value NUMERIC,
    PRIMARY KEY (transaction_hash, log_index)
);

CREATE TABLE CONTRACTS (
    address VARCHAR(42) REFERENCES ADDRESSES(address),
    version NUMERIC,
    function_sighashes VARCHAR(1024), -- 4 bytes on blockchain
    bytecode VARCHAR(8192),
    is_erc20 BOOLEAN,
    is_erc721 BOOLEAN,
    block_hash VARCHAR(66) REFERENCES BLOCKS(hash),
    PRIMARY KEY (address, version)
);

CREATE INDEX contracts_address_index ON CONTRACTS(address); 

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
-- replace slice_name with the slice you intend to use
\copy addresses_import FROM '/file_path/adjusted_balance_slice_name_filtered.json';
\copy blocks_import FROM '/file_path/slice_name_blocks.json';
\copy contracts_import FROM '/file_path/adjusted_contracts_slice_name_filtered.json';
\copy token_transactions_import FROM '/file_path/slice_name_token_transactions.json';
\copy tokens_import FROM '/file_path/adjusted_tokens_slice_name_filtered.json';
\copy transactions_import FROM '/file_path/slice_name_transactions.json';
\copy withdrawals_import FROM '/file_path/slice_name_withdrawals.json';

-- Insert data into actual tables from unlogged tables
-- Addresses
INSERT INTO addresses (address, eth_balance, adjusted)
SELECT (doc->>'address')::VARCHAR(42), (doc->>'eth_balance')::NUMERIC, (doc->>'adjusted')::BOOLEAN FROM addresses_import;

-- -- Blocks
INSERT INTO blocks (hash, number, timestamp, extra_data, base_fee_per_gas, size, miner)
SELECT (doc->>'hash')::VARCHAR(66), (doc->>'number')::NUMERIC, TO_TIMESTAMP((doc->>'timestamp'), 'YYYY-MM-DD HH24:MI:SS UTC')::TIMESTAMP WITH TIME ZONE, (doc->>'extra_data')::VARCHAR(8192), (doc->>'base_fee_per_gas')::NUMERIC, (doc->>'size')::NUMERIC, (doc->>'miner')::VARCHAR(42) FROM blocks_import;

-- -- Contracts
INSERT INTO contracts (address, function_sighashes, bytecode, is_erc20, is_erc721, block_hash, version)
SELECT (doc->>'address')::VARCHAR(42), (doc->>'function_sighashes')::VARCHAR(1024), (doc->>'bytecode')::VARCHAR(8192), (doc->>'is_erc20')::BOOLEAN, (doc->>'is_erc721')::BOOLEAN, (doc->>'block_hash')::VARCHAR(66), (doc->>'version')::NUMERIC FROM contracts_import;

-- -- Transactions
INSERT INTO transactions (hash, transaction_index, value, from_address, to_address, gas, max_priority_fee_per_gas, input, block_hash, transaction_type, nonce)
SELECT (doc->>'hash')::VARCHAR(66), (doc->>'transaction_index')::NUMERIC, (doc->>'value')::NUMERIC, (doc->>'from_address')::VARCHAR(42), (doc->>'to_address')::VARCHAR(42), (doc->>'gas')::NUMERIC, (doc->>'max_priority_fee_per_gas')::NUMERIC, (doc->>'input')::VARCHAR(8192), (doc->>'block_hash')::VARCHAR(66), (doc->>'transaction_type')::NUMERIC, (doc->>'nonce')::NUMERIC FROM transactions_import;

-- -- Tokens
INSERT INTO tokens (address, symbol, name, decimals, total_supply, block_hash, missing_from_bq)
SELECT (doc->>'address')::VARCHAR(42), (doc->>'symbol')::VARCHAR(20), (doc->>'name')::VARCHAR(100), (doc->>'decimals')::NUMERIC, (doc->>'total_supply')::NUMERIC, (doc->>'block_hash')::VARCHAR(66), (doc->>'missing_from_bq')::BOOLEAN FROM tokens_import;

-- -- Token Transactions
INSERT INTO token_transactions (transaction_hash, log_index, token_address, value)
SELECT (doc->>'transaction_hash')::VARCHAR(66), (doc->>'log_index')::NUMERIC, (doc->>'token_address')::VARCHAR(42), (doc->>'value')::NUMERIC FROM token_transactions_import;

-- -- Withdrawals
INSERT INTO withdrawals (hash, withdrawal_index, validator, address, amount)
SELECT (doc->>'hash')::VARCHAR(66), (doc->>'withdrawal_index')::NUMERIC, (doc->>'validator')::NUMERIC, (doc->>'address')::VARCHAR(42), (doc->>'amount')::NUMERIC FROM withdrawals_import;

DROP TABLE addresses_import, blocks_import, contracts_import, token_transactions_import, tokens_import, transactions_import, withdrawals_import;