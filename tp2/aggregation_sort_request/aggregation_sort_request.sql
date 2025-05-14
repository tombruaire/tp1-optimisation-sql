EXPLAIN ANALYZE
SELECT 
    tb.startYear, 
    COUNT(*) AS film_count, 
    AVG(tr.averageRating) AS average_rating
FROM 
    title_basics tb
JOIN 
    title_ratings tr ON tb.tconst = tr.tconst
WHERE 
    tb.startYear BETWEEN 1990 AND 2000
    AND tb.titleType = 'movie'
GROUP BY 
    tb.startYear
ORDER BY 
    average_rating DESC;
