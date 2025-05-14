-- Analysis of the distribution of release years by decade
-- Calculation of the number of films per decade and sorting by number in descending order

SELECT 
    (startyear / 10) * 10 AS decade,
    COUNT(*) AS number_of_titles,
    COUNT(*) FILTER (WHERE titletype = 'movie') AS number_of_movies
FROM 
    title_basics
WHERE 
    startyear IS NOT NULL 
    AND startyear > 0
GROUP BY 
    decade
ORDER BY 
    decade DESC;

-- More detailed analysis for a recent decade identified as having a lot of films
-- (to execute after identifying an interesting decade)

SELECT 
    startyear,
    COUNT(*) AS number_of_titles,
    COUNT(*) FILTER (WHERE titletype = 'movie') AS number_of_movies
FROM 
    title_basics
WHERE 
    startyear BETWEEN 2010 AND 2019  -- Example for the decade 2010
GROUP BY 
    startyear
ORDER BY 
    startyear;

-- 1. Query to analyze performance within the targeted period (2010-2019, movies only)
EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE startyear BETWEEN 2010 AND 2019
AND titletype = 'movie'
ORDER BY startyear;

-- 2. Query to analyze performance outside the targeted period
EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE (startyear < 2010 OR startyear > 2019)
AND titletype = 'movie'
ORDER BY startyear;

-- 3. Query to compare the size of the two indexes
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM 
    pg_indexes
WHERE 
    tablename = 'title_basics'
    AND (indexname = 'idx_title_basics_movies_2010s' OR indexname = 'idx_title_basics_startyear');

-- Additional statistics on the indexes
SELECT 
    indexname,
    indexdef
FROM 
    pg_indexes
WHERE 
    tablename = 'title_basics'
    AND (indexname = 'idx_title_basics_movies_2010s' OR indexname = 'idx_title_basics_startyear');
