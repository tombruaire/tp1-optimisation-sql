-- Research of titles insensitive to case
EXPLAIN ANALYZE
SELECT *
FROM title_basics
WHERE LOWER(primarytitle) LIKE LOWER('%Star Wars%');
