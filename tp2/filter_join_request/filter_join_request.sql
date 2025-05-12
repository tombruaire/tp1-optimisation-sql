EXPLAIN ANALYZE
SELECT tb.primaryTitle, tr.averageRating
FROM title_basics tb
JOIN title_ratings tr ON tb.tconst = tr.tconst
WHERE tb.startYear = 1994
AND tr.averageRating > 8.5
ORDER BY tr.averageRating DESC;
