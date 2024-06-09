-- replace X and Y with integers
SELECT COUNT(DISTINCT t_t.token_address)
FROM Blocks b, Transactions t, token_transactions t_t
WHERE b.hash = t.block_hash
AND t.hash = t_t.transaction_hash
AND b.number BETWEEN X AND Y;