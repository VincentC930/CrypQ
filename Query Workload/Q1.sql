SELECT COUNT(*)
FROM Transactions t, Tokens, Token_Transactions t_t, Contracts c, Addresses a
WHERE t.hash = t_t.transaction_hash
AND t_t.token_address = tokens.address
AND t.to_address = c.address
AND t.from_address = a.address
AND t.nonce BETWEEN 2100000 AND 4200000
AND t_t.value BETWEEN 1000000000 AND 10000000000
AND tokens.name NOT LIKE '%US%'
AND c.is_erc20 = TRUE
AND a.eth_balance > 25000000000000000;