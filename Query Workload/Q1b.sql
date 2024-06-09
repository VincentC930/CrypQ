-- replace A - F with integers
SELECT COUNT(*)
FROM Addresses a, Transactions t, Token_Transactions t_t
WHERE t.from_address = a.address
AND t.hash = t_t.transaction_hash
AND a.eth_balance BETWEEN A AND B
AND t.nonce BETWEEN C AND D
AND t_t.value BETWEEN E AND F;