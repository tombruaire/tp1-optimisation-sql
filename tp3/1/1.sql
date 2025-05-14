-- Test 1: Prefix (already present)
EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE primaryTitle LIKE 'The%';

-- Test 2: Exact match
EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE primaryTitle = 'The Godfather';

-- Test 3: Suffix
EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE primaryTitle LIKE '%The';

-- Test 4: Substring
EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE primaryTitle LIKE '%The%';

-- Test 5: Order
EXPLAIN ANALYZE
SELECT *
FROM title_basics
ORDER BY primaryTitle
LIMIT 100;
