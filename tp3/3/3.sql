EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE genres LIKE '%Drama%'
AND startYear = 1994;

EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE genres LIKE '%Drama%';

EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE startYear = 1994;

EXPLAIN ANALYZE
SELECT *
FROM title_basics
ORDER BY genres, startYear;

EXPLAIN ANALYZE
SELECT *
FROM title_basics
ORDER BY startYear, genres;
