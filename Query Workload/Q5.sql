WITH Popular_Tokens AS (
	SELECT tokens.address token_address, tokens.symbol token_symbol, COUNT(*) transactions
	FROM Tokens tokens, Transactions t, Token_Transactions t_t
	WHERE t.hash = t_t.transaction_hash
	AND t_t.token_address = tokens.address
	GROUP BY tokens.address, tokens.symbol
	ORDER BY COUNT(*) DESC
	LIMIT 10
),
Ranked_Users AS (
	SELECT p_t.TOKEN_ADDRESS, p_t.TOKEN_SYMBOL, t.FROM_ADDRESS, SUM(t_t.VALUE) AS TOKENS_SENT, ROW_NUMBER() OVER (PARTITION BY p_t.TOKEN_ADDRESS, p_t.TOKEN_SYMBOL ORDER BY SUM(t_t.VALUE) DESC) AS ranking
	FROM Popular_Tokens p_t, Transactions t, Token_Transactions t_t
    WHERE t.hash = t_t.transaction_hash
	AND t_t.token_address = p_t.token_address
  	GROUP BY p_t.token_address, p_t.token_symbol, t.from_address
)
SELECT token_address, token_symbol, from_address AS user, tokens_sent, ranking
FROM Ranked_Users
WHERE ranking <= 10
ORDER BY token_address, token_symbol, ranking;
