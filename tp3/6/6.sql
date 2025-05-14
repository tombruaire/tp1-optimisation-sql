-- Request which selects some columns by filtering on the genre
-- This request retrieves the title and year of action films released after 2000
EXPLAIN ANALYZE
SELECT primarytitle, startyear
FROM title_basics
WHERE genres LIKE 'Action%'
AND startyear > 2000;
