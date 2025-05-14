-- Simple request searching for all titles containing the word "love"
EXPLAIN ANALYZE
SELECT tconst, primarytitle, startyear, genres
FROM title_basics
WHERE primarytitle LIKE '%love%'
ORDER BY startyear DESC
LIMIT 100;

-- Full-text search request
EXPLAIN ANALYZE
SELECT * FROM title_basics
WHERE to_tsvector('english', primarytitle) @@ to_tsquery('english', 'love')
ORDER BY startyear DESC
LIMIT 100;