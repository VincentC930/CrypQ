-- replace X with an integer
SELECT a.address, a.eth_balance, c.address, tokens.symbol, t_t.value
FROM Addresses a, Blocks b, Transactions t, Token_Transactions t_t, Tokens tokens, Contracts c
WHERE a.address = t.from_address 
AND t.to_address = c.address
AND t.hash = t_t.transaction_hash
AND t_t.token_address = tokens.address
AND c.is_erc20 = TRUE
AND t_t.value > X;
