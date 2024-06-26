INSERT INTO CURR_BLOCKS
SELECT *
FROM BLOCKS
WHERE NUMBER = {curr_update_block};

INSERT INTO CURR_TRANSACTIONS
SELECT *
FROM TRANSACTIONS
WHERE BLOCK_HASH = (
    SELECT HASH
    FROM BLOCKS
    WHERE NUMBER = {curr_update_block}
);

WITH NEWLY_CREATED_TOKENS AS (
    SELECT TOKENS.ADDRESS AS ADDRESS
    FROM CURR_BLOCKS, TOKENS
    WHERE CURR_BLOCKS.HASH = TOKENS.BLOCK_HASH
    AND CURR_BLOCKS.NUMBER = {curr_update_block}
),
NEWLY_REFERENCED_TOKENS AS (
    SELECT TOKEN_TRANSACTIONS.TOKEN_ADDRESS AS ADDRESS
    FROM CURR_BLOCKS, CURR_TRANSACTIONS, TOKEN_TRANSACTIONS
    WHERE CURR_BLOCKS.HASH = CURR_TRANSACTIONS.BLOCK_HASH
    AND CURR_TRANSACTIONS.HASH = TOKEN_TRANSACTIONS.TRANSACTION_HASH
    AND CURR_BLOCKS.NUMBER = {curr_update_block}
),
TOKENS_TO_ADD AS (
    (SELECT ADDRESS
    FROM NEWLY_CREATED_TOKENS
    EXCEPT
    SELECT ADDRESS
    FROM CURR_TOKENS)
    UNION
    (SELECT ADDRESS
    FROM NEWLY_REFERENCED_TOKENS
    EXCEPT
    SELECT ADDRESS
    FROM CURR_TOKENS)
)
INSERT INTO CURR_TOKENS
SELECT *
FROM TOKENS
WHERE ADDRESS IN (SELECT * FROM TOKENS_TO_ADD);

WITH NEW_TOKEN_TRANSACTIONS AS (
    SELECT TOKEN_TRANSACTIONS.TRANSACTION_HASH
    FROM CURR_BLOCKS, CURR_TRANSACTIONS, TOKEN_TRANSACTIONS
    WHERE CURR_BLOCKS.HASH = CURR_TRANSACTIONS.BLOCK_HASH
    AND CURR_TRANSACTIONS.HASH = TOKEN_TRANSACTIONS.TRANSACTION_HASH
    AND CURR_BLOCKS.NUMBER = {curr_update_block}
)
INSERT INTO CURR_TOKEN_TRANSACTIONS
SELECT *
FROM TOKEN_TRANSACTIONS
WHERE TRANSACTION_HASH IN (SELECT TRANSACTION_HASH FROM NEW_TOKEN_TRANSACTIONS);

WITH NEWLY_CREATED_CONTRACTS AS (
    SELECT CONTRACTS.ADDRESS AS ADDRESS
    FROM CURR_BLOCKS, CONTRACTS
    WHERE CURR_BLOCKS.HASH = CONTRACTS.BLOCK_HASH
    AND CURR_BLOCKS.NUMBER = {curr_update_block}
),
NEWLY_REFERENCED_CONTRACTS AS (
    SELECT CURR_TRANSACTIONS.TO_ADDRESS AS ADDRESS
    FROM CURR_BLOCKS, CURR_TRANSACTIONS, CONTRACTS
    WHERE CURR_BLOCKS.HASH = CURR_TRANSACTIONS.BLOCK_HASH
	AND CURR_TRANSACTIONS.TO_ADDRESS = CONTRACTS.ADDRESS
    AND CURR_BLOCKS.NUMBER = {curr_update_block}
),
CONTRACTS_TO_ADD AS (
    (SELECT ADDRESS
    FROM NEWLY_CREATED_CONTRACTS
    EXCEPT
    SELECT ADDRESS
    FROM CURR_CONTRACTS)
    UNION
    (SELECT ADDRESS
    FROM NEWLY_REFERENCED_CONTRACTS
    EXCEPT
    SELECT ADDRESS
    FROM CURR_CONTRACTS)
)
INSERT INTO CURR_CONTRACTS
SELECT *
FROM CONTRACTS
WHERE ADDRESS IN (SELECT * FROM CONTRACTS_TO_ADD);

INSERT INTO CURR_WITHDRAWALS
SELECT *
FROM WITHDRAWALS
WHERE HASH = (
    SELECT HASH
    FROM BLOCKS
    WHERE NUMBER = {curr_update_block}
);

CREATE TEMPORARY TABLE Temp_Relevant_From_Updated AS
SELECT DISTINCT from_address AS address
FROM TRANSACTIONS
JOIN BLOCKS ON TRANSACTIONS.block_hash = BLOCKS.hash
WHERE BLOCKS.number BETWEEN {curr_update_block - 999} AND {curr_update_block};

CREATE TEMPORARY TABLE Temp_Relevant_To_Updated AS
SELECT DISTINCT to_address AS address
FROM TRANSACTIONS
JOIN BLOCKS ON TRANSACTIONS.block_hash = BLOCKS.hash
WHERE BLOCKS.number BETWEEN {curr_update_block - 999} AND {curr_update_block};

CREATE TEMPORARY TABLE Temp_Relevant_Miner_Updated AS
SELECT DISTINCT miner AS address
FROM BLOCKS
WHERE number BETWEEN {curr_update_block - 999} AND {curr_update_block};

CREATE TEMPORARY TABLE Temp_Relevant_Withdrawals_Updated AS
SELECT DISTINCT withdrawals.address
FROM WITHDRAWALS
JOIN BLOCKS ON WITHDRAWALS.hash = BLOCKS.hash
WHERE BLOCKS.number BETWEEN {curr_update_block - 999} AND {curr_update_block};

CREATE TEMPORARY TABLE Temp_Contract_Addresses_Updated AS
SELECT contracts.address
FROM BLOCKS
JOIN TRANSACTIONS ON BLOCKS.hash = TRANSACTIONS.block_hash
JOIN CONTRACTS ON TRANSACTIONS.to_address = CONTRACTS.address
WHERE BLOCKS.number BETWEEN {curr_update_block - 999} AND {curr_update_block}
UNION
SELECT contracts.address
FROM CONTRACTS, BLOCKS
WHERE CONTRACTS.BLOCK_HASH = BLOCKS.HASH
AND BLOCKS.number BETWEEN {curr_update_block - 999} AND {curr_update_block};

CREATE TEMPORARY TABLE Temp_Relevant_Address_Updated AS
SELECT address FROM Temp_Relevant_From_Updated
UNION
SELECT address FROM Temp_Relevant_To_Updated
UNION
SELECT address FROM Temp_Relevant_Miner_Updated
UNION
SELECT address FROM Temp_Relevant_Withdrawals_Updated
UNION 
SELECT address FROM Temp_Contract_Addresses_Updated;

CREATE TEMPORARY TABLE Temp_Relevant_From_Current AS
SELECT DISTINCT from_address AS address
FROM TRANSACTIONS
JOIN BLOCKS ON TRANSACTIONS.block_hash = BLOCKS.hash
WHERE BLOCKS.number BETWEEN {curr_update_block - 1000} AND {curr_update_block - 1};

CREATE TEMPORARY TABLE Temp_Relevant_To_Current AS
SELECT DISTINCT to_address AS address
FROM TRANSACTIONS
JOIN BLOCKS ON TRANSACTIONS.block_hash = BLOCKS.hash
WHERE BLOCKS.number BETWEEN {curr_update_block - 1000} AND {curr_update_block - 1};

CREATE TEMPORARY TABLE Temp_Relevant_Miner_Current AS
SELECT DISTINCT miner AS address
FROM BLOCKS
WHERE number BETWEEN {curr_update_block - 1000} AND {curr_update_block - 1};

CREATE TEMPORARY TABLE Temp_Relevant_Withdrawals_Current AS
SELECT DISTINCT withdrawals.address
FROM WITHDRAWALS
JOIN BLOCKS ON WITHDRAWALS.hash = BLOCKS.hash
WHERE BLOCKS.number BETWEEN {curr_update_block - 1000} AND {curr_update_block - 1};

CREATE TEMPORARY TABLE Temp_Contract_Addresses_Current AS
SELECT contracts.address
FROM BLOCKS
JOIN TRANSACTIONS ON BLOCKS.hash = TRANSACTIONS.block_hash
JOIN CONTRACTS ON TRANSACTIONS.to_address = CONTRACTS.address
WHERE BLOCKS.number BETWEEN {curr_update_block - 1000} AND {curr_update_block - 1}
UNION
SELECT contracts.address
FROM CONTRACTS, BLOCKS
WHERE CONTRACTS.BLOCK_HASH = BLOCKS.HASH
AND BLOCKS.number BETWEEN {curr_update_block - 1000} AND {curr_update_block - 1};

CREATE TEMPORARY TABLE Temp_Relevant_Address_Current AS
SELECT address FROM Temp_Relevant_From_Current
UNION
SELECT address FROM Temp_Relevant_To_Current
UNION
SELECT address FROM Temp_Relevant_Miner_Current
UNION
SELECT address FROM Temp_Relevant_Withdrawals_Current
UNION 
SELECT address FROM Temp_Contract_Addresses_Current;

WITH ADDRESSES_TO_INSERT AS (
    SELECT * FROM Temp_Relevant_Address_Updated
    EXCEPT
    SELECT * FROM Temp_Relevant_Address_Current
)
INSERT INTO CURR_ADDRESSES
SELECT *
FROM ADDRESSES
WHERE ADDRESS IN (SELECT * FROM ADDRESSES_TO_INSERT);

WITH SentInNewBlock AS (
    SELECT from_address AS address, SUM(value) AS total_sent
    FROM CURR_TRANSACTIONS
    WHERE BLOCK_HASH = (
        SELECT HASH
        FROM BLOCKS
        WHERE NUMBER = {curr_update_block}
    )
    GROUP BY from_address
),
ReceivedInNewBlock AS (
    SELECT to_address AS address, SUM(value) AS total_received
    FROM CURR_TRANSACTIONS
    WHERE BLOCK_HASH = (
        SELECT HASH
        FROM BLOCKS
        WHERE NUMBER = {curr_update_block}
    )
    GROUP BY to_address
),
RelevantAddresses AS (
    SELECT *
    FROM CURR_ADDRESSES C
    WHERE C.ADDRESS IN (SELECT ADDRESS FROM SentInNewBlock) OR C.ADDRESS IN (SELECT ADDRESS FROM ReceivedInNewBlock)
)
UPDATE CURR_ADDRESSES
SET ETH_BALANCE = C.ETH_BALANCE + COALESCE(R.total_received, 0) - COALESCE(S.total_sent, 0)
FROM RelevantAddresses C
LEFT OUTER JOIN SentInNewBlock S ON C.ADDRESS = S.ADDRESS
LEFT OUTER JOIN ReceivedInNewBlock R ON C.ADDRESS = R.ADDRESS;

-- Update ADDRESSES table with values from CURR_ADDRESSES
UPDATE ADDRESSES
SET ETH_BALANCE = CURR_ADDRESSES.ETH_BALANCE
FROM CURR_ADDRESSES
WHERE ADDRESSES.ADDRESS = CURR_ADDRESSES.ADDRESS;

-- updates to avoid violation of foreign key constraints
CREATE TEMPORARY TABLE Temp_Tokens_From_Deleted_Block AS
SELECT CURR_TOKENS.ADDRESS
FROM CURR_BLOCKS, CURR_TOKENS
WHERE CURR_BLOCKS.HASH = CURR_TOKENS.BLOCK_HASH
AND CURR_BLOCKS.NUMBER = {curr_update_block - 1000};

UPDATE CURR_TOKENS
SET BLOCK_HASH = NULL
WHERE ADDRESS IN (SELECT ADDRESS FROM Temp_Tokens_From_Deleted_Block);

UPDATE TOKENS
SET BLOCK_HASH = NULL
WHERE ADDRESS IN (SELECT ADDRESS FROM Temp_Tokens_From_Deleted_Block);

CREATE TEMPORARY TABLE Temp_Contracts_From_Deleted_Block AS
SELECT CURR_CONTRACTS.ADDRESS
FROM CURR_BLOCKS, CURR_CONTRACTS
WHERE CURR_BLOCKS.HASH = CURR_CONTRACTS.BLOCK_HASH;

UPDATE CURR_CONTRACTS
SET BLOCK_HASH = NULL
WHERE ADDRESS IN (SELECT ADDRESS FROM Temp_CONTRACTS_From_Deleted_Block);

UPDATE CONTRACTS
SET BLOCK_HASH = NULL
WHERE ADDRESS IN (SELECT ADDRESS FROM Temp_CONTRACTS_From_Deleted_Block);

-- deletes
CREATE TEMPORARY TABLE TEMP_TOKEN_TRANSACTIONS_TO_DETELE AS
SELECT CURR_TOKEN_TRANSACTIONS.TRANSACTION_HASH
FROM CURR_BLOCKS, CURR_TRANSACTIONS, CURR_TOKEN_TRANSACTIONS
WHERE CURR_BLOCKS.HASH = CURR_TRANSACTIONS.HASH
AND CURR_TRANSACTIONS.HASH = CURR_TOKEN_TRANSACTIONS.TRANSACTION_HASH
AND CURR_BLOCKS.NUMBER = {curr_update_block - 1000};

DELETE FROM CURR_TOKEN_TRANSACTIONS
WHERE TRANSACTION_HASH IN (SELECT * FROM TEMP_TOKEN_TRANSACTIONS_TO_DETELE);

WITH TOKENS_REFERENCED_IN_DELETED_TRANSACTIONS AS (
    SELECT TOKEN_TRANSACTIONS.TOKEN_ADDRESS 
    FROM TEMP_TOKEN_TRANSACTIONS_TO_DETELE, TOKEN_TRANSACTIONS
	WHERE TEMP_TOKEN_TRANSACTIONS_TO_DETELE.TRANSACTION_HASH = TOKEN_TRANSACTIONS.TRANSACTION_HASH
),
TOKENS_CREATED_IN_DELETED_BLOCK AS (
    SELECT ADDRESS
    FROM Temp_Tokens_From_Deleted_Block
),
TOKENS_CREATED_IN_UPDATED_WINDOW AS (
    SELECT CURR_TOKENS.ADDRESS
    FROM CURR_BLOCKS, CURR_TOKENS
    WHERE CURR_BLOCKS.HASH = CURR_TOKENS.BLOCK_HASH
    AND CURR_BLOCKS.NUMBER BETWEEN {curr_update_block - 999} AND {curr_update_block}
), 
TOKENS_REFERENCED_IN_UPDATED_WINDOW AS (
    SELECT CURR_TOKENS.ADDRESS
    FROM CURR_BLOCKS, CURR_TRANSACTIONS, CURR_TOKEN_TRANSACTIONS, CURR_TOKENS
    WHERE CURR_BLOCKS.HASH = CURR_TRANSACTIONS.BLOCK_HASH
    AND CURR_TRANSACTIONS.HASH = CURR_TOKEN_TRANSACTIONS.TRANSACTION_HASH
    AND CURR_TOKEN_TRANSACTIONS.TOKEN_ADDRESS = CURR_TOKENS.ADDRESS
    AND CURR_BLOCKS.NUMBER BETWEEN {curr_update_block - 999} AND {curr_update_block}
),
TOKENS_TO_DELETE AS (
    (SELECT * FROM TOKENS_REFERENCED_IN_DELETED_TRANSACTIONS
    UNION
    SELECT * FROM TOKENS_CREATED_IN_DELETED_BLOCK)
    EXCEPT
    (SELECT * FROM TOKENS_CREATED_IN_UPDATED_WINDOW
    UNION
    SELECT * FROM TOKENS_REFERENCED_IN_UPDATED_WINDOW)
)
DELETE FROM CURR_TOKENS
WHERE ADDRESS IN (SELECT * FROM TOKENS_TO_DELETE);

CREATE TEMPORARY TABLE TEMP_TRANSACTIONS_TO_DELETE AS
SELECT CURR_TRANSACTIONS.HASH
FROM CURR_BLOCKS, CURR_TRANSACTIONS
WHERE CURR_BLOCKS.HASH = CURR_TRANSACTIONS.BLOCK_HASH
AND CURR_BLOCKS.NUMBER = {curr_update_block - 1000};

DELETE FROM CURR_TRANSACTIONS
WHERE HASH IN (SELECT * FROM TEMP_TRANSACTIONS_TO_DELETE);

WITH CONTRACTS_REFERENCED_IN_DELETED_TRANSACTIONS AS (
    SELECT TOKEN_TRANSACTIONS.TOKEN_ADDRESS 
    FROM TEMP_TOKEN_TRANSACTIONS_TO_DETELE, TOKEN_TRANSACTIONS
	WHERE TEMP_TOKEN_TRANSACTIONS_TO_DETELE.TRANSACTION_HASH = TOKEN_TRANSACTIONS.TRANSACTION_HASH
),
CONTRACTS_CREATED_IN_DELETED_BLOCK AS (
    SELECT ADDRESS
    FROM Temp_Contracts_From_Deleted_Block
),
CONTRACTS_CREATED_IN_UPDATED_WINDOW AS (
    SELECT CURR_CONTRACTS.ADDRESS
    FROM CURR_BLOCKS, CURR_CONTRACTS
    WHERE CURR_BLOCKS.HASH = CURR_CONTRACTS.BLOCK_HASH
    AND CURR_BLOCKS.NUMBER BETWEEN {curr_update_block - 999} AND {curr_update_block}
), 
CONTRACTS_REFERENCED_IN_UPDATED_WINDOW AS (
    SELECT CURR_CONTRACTS.ADDRESS
    FROM CURR_BLOCKS, CURR_TRANSACTIONS, CURR_CONTRACTS
    WHERE CURR_BLOCKS.HASH = CURR_TRANSACTIONS.BLOCK_HASH
    AND CURR_TRANSACTIONS.TO_ADDRESS = CURR_CONTRACTS.ADDRESS
    AND CURR_BLOCKS.NUMBER BETWEEN {curr_update_block - 999} AND {curr_update_block}
),
CONTRACTS_TO_DELETE AS (
    (SELECT * FROM CONTRACTS_REFERENCED_IN_DELETED_TRANSACTIONS
    UNION
    SELECT * FROM CONTRACTS_CREATED_IN_DELETED_BLOCK)
    EXCEPT
    (SELECT * FROM CONTRACTS_CREATED_IN_UPDATED_WINDOW
    UNION
    SELECT * FROM CONTRACTS_REFERENCED_IN_UPDATED_WINDOW)
)
DELETE FROM CURR_CONTRACTS
WHERE ADDRESS IN (SELECT * FROM CONTRACTS_TO_DELETE);


DELETE FROM CURR_WITHDRAWALS
WHERE HASH = (SELECT HASH FROM CURR_BLOCKS WHERE NUMBER =  {curr_update_block});

DELETE FROM CURR_BLOCKS WHERE NUMBER = {curr_update_block - 1000};

WITH ADDRESSES_TO_DELETE AS (
    Temp_Contract_Addresses_Current
    EXCEPT
    Temp_Contract_Addresses_Updated
)
INSERT INTO CURR_ADDRESSES
SELECT *
FROM ADDRESSES
WHERE ADDRESS IN (SELECT * FROM ADDRESSES_TO_DELETE);

DROP TABLE IF EXISTS Temp_Relevant_From_Updated CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_To_Updated CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_Miner_Updated CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_Withdrawals_Updated CASCADE;
DROP TABLE IF EXISTS Temp_Contract_Addresses_Updated CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_Address_Updated CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_From_Current CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_To_Current CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_Miner_Current CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_Withdrawals_Current CASCADE;
DROP TABLE IF EXISTS Temp_Contract_Addresses_Current CASCADE;
DROP TABLE IF EXISTS Temp_Relevant_Address_Current CASCADE;
DROP TABLE IF EXISTS TEMP_TOKEN_TRANSACTIONS_TO_DETELE CASCADE;
DROP TABLE IF EXISTS Temp_Tokens_From_Deleted_Block CASCADE;
DROP TABLE IF EXISTS Temp_Contracts_From_Deleted_Block CASCADE;
DROP TABLE IF EXISTS TEMP_TRANSACTIONS_TO_DELETE CASCADE;