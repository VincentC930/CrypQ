WITH Creation AS (
	SELECT c.address AS address, c.version AS version, b.number AS number
	FROM Contracts c, Blocks b
	WHERE c.block_hash = b.hash
),
First_used AS (
	SELECT c.address AS address, c.version AS version, MIN(b.number) AS number
	FROM Contracts c, Blocks b, Transactions t
	WHERE (t.from_address = c.address OR t.to_address = c.address)
	AND t.block_hash = b.hash
	GROUP BY c.address, c.version
)
SELECT AVG(First_used.number - Creation.number)
FROM Creation, First_used
WHERE Creation.address = First_used.address
AND Creation.version = First_used.version;