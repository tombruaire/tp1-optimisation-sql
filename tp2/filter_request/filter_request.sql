EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE titleType = 'movie' AND startYear = 1950;


EXPLAIN ANALYZE
SELECT tconst, primaryTitle, startYear, titleType
FROM title_basics
WHERE titleType = 'movie' AND startYear = 1950;
