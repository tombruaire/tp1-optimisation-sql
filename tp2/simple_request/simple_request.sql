EXPLAIN ANALYZE
SELECT
    *
FROM
    title_basics
WHERE
    startYear = 2020;


EXPLAIN ANALYZE
SELECT
    tconst,
    primaryTitle,
    startYear
FROM
    title_basics
WHERE
    startYear = 2020;