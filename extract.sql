CREATE OR REPLACE TABLE crypto_ethereum_slice.recent_blocks AS SELECT *
FROM `bigquery-public-data.crypto_ethereum.blocks` ORDER BY timestamp DESC
LIMIT 1000;

-- flatten withdrawls array from blocks table
CREATE OR REPLACE TABLE crypto_ethereum_slice.recent_withdrawals AS
SELECT
  rb.hash,
  withdrawal.index AS withdrawal_index,
  withdrawal.validator_index AS validator,
  withdrawal.address AS address,
  withdrawal.amount AS amount
FROM
  crypto_ethereum_slice.recent_blocks AS rb,
  UNNEST(rb.withdrawals) AS withdrawal;

CREATE OR REPLACE TABLE crypto_ethereum_slice.recent_transactions AS
SELECT Transactions.*
FROM `bigquery-public-data.crypto_ethereum.transactions` AS Transactions
WHERE block_hash IN (SELECT recent_blocks.hash FROM crypto_ethereum_slice.recent_blocks);

CREATE OR REPLACE TABLE crypto_ethereum_slice.recent_contracts AS
SELECT Contracts.*
FROM `bigquery-public-data.crypto_ethereum.contracts` AS Contracts
WHERE address IN (SELECT from_address FROM crypto_ethereum_slice.recent_transactions)
   OR address IN (SELECT to_address FROM crypto_ethereum_slice.recent_transactions)
   OR block_hash IN (SELECT recent_blocks.hash FROM crypto_ethereum_slice.recent_blocks);

CREATE OR REPLACE TABLE crypto_ethereum_slice.recent_addresses AS
SELECT Addresses.*
FROM `bigquery-public-data.crypto_ethereum.balances` AS Addresses
WHERE address IN (SELECT from_address FROM crypto_ethereum_slice.recent_transactions)
   OR address IN (SELECT to_address FROM crypto_ethereum_slice.recent_transactions)
   OR address IN (SELECT miner FROM crypto_ethereum_slice.recent_blocks)
   OR address IN (SELECT address FROM crypto_ethereum_slice.recent_contracts)
   OR address IN (SELECT address FROM crypto_ethereum_slice.recent_withdrawals);

CREATE OR REPLACE TABLE crypto_ethereum_slice.recent_token_transactions AS
SELECT Token_Transactions.*
FROM `bigquery-public-data.crypto_ethereum.token_transfers` AS Token_Transactions
WHERE transaction_hash IN (SELECT recent_transactions.hash FROM crypto_ethereum_slice.recent_transactions);

CREATE OR REPLACE TABLE crypto_ethereum_slice.recent_tokens AS
SELECT Tokens.*
FROM `bigquery-public-data.crypto_ethereum.tokens` AS Tokens
WHERE address IN (SELECT token_address FROM crypto_ethereum_slice.recent_token_transactions)
   OR block_hash IN (SELECT recent_blocks.hash FROM crypto_ethereum_slice.recent_blocks);