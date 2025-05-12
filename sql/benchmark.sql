-- Fichier de benchmark pour mesurer les performances des requêtes SQL
-- Exécutez chaque requête séparément et notez le temps d'exécution
-- Activer le chronométrage des requêtes
\ timing on -- 1. Requête basique sur title_basics (table volumineuse)
EXPLAIN ANALYZE
SELECT
    *
FROM
    title_basics
WHERE
    startYear = 2020;

-- 2. Jointure entre title_basics et title_ratings
EXPLAIN ANALYZE
SELECT
    tb.primaryTitle,
    tr.averageRating,
    tr.numVotes
FROM
    title_basics tb
    JOIN title_ratings tr ON tb.tconst = tr.tconst
WHERE
    tr.averageRating > 8.0
    AND tb.startYear > 2010;

-- 3. Jointure complexe entre plusieurs tables volumineuses
EXPLAIN ANALYZE
SELECT
    tb.primaryTitle,
    nb.primaryName,
    tp.category
FROM
    title_basics tb
    JOIN title_principals tp ON tb.tconst = tp.tconst
    JOIN name_basics nb ON tp.nconst = nb.nconst
WHERE
    tb.startYear = 2019
LIMIT
    100;

-- 4. Requête avec agrégation
EXPLAIN ANALYZE
SELECT
    startYear,
    COUNT(*) as movie_count,
    AVG(tr.averageRating) as avg_rating
FROM
    title_basics tb
    JOIN title_ratings tr ON tb.tconst = tr.tconst
WHERE
    tb.titleType = 'movie'
    AND tb.startYear BETWEEN 2000
    AND 2020
GROUP BY
    startYear
ORDER BY
    startYear;

-- 5. Recherche par titre (cas d'utilisation fréquent)
EXPLAIN ANALYZE
SELECT
    *
FROM
    title_basics
WHERE
    primaryTitle LIKE '%Star Wars%';

-- 6. Requête sur la table title_principals (la plus volumineuse)
EXPLAIN ANALYZE
SELECT
    tp.*,
    nb.primaryName
FROM
    title_principals tp
    JOIN name_basics nb ON tp.nconst = nb.nconst
WHERE
    tp.category = 'actor'
LIMIT
    1000;

-- 7. Requête sur title_akas (deuxième plus volumineuse)
EXPLAIN ANALYZE
SELECT
    *
FROM
    title_akas
WHERE
    region = 'US'
    AND language = 'en'
LIMIT
    1000;

-- 8. Requête avec sous-requête
EXPLAIN ANALYZE
SELECT
    primaryTitle,
    startYear
FROM
    title_basics
WHERE
    tconst IN (
        SELECT
            tconst
        FROM
            title_ratings
        WHERE
            numVotes > 100000
    )
ORDER BY
    startYear DESC;

-- 9. Requête avec filtrage complexe
EXPLAIN ANALYZE
SELECT
    DISTINCT tb.primaryTitle,
    tb.startYear,
    tr.averageRating
FROM
    title_basics tb
    JOIN title_ratings tr ON tb.tconst = tr.tconst
WHERE
    tb.genres LIKE '%Action%'
    AND tb.startYear > 2015
    AND tr.averageRating > 7.0
ORDER BY
    tr.averageRating DESC
LIMIT
    100;

-- 10. Requête avec jointure sur plusieurs conditions
EXPLAIN ANALYZE
SELECT
    tb.primaryTitle,
    te.seasonNumber,
    te.episodeNumber
FROM
    title_basics tb
    JOIN title_episode te ON tb.tconst = te.tconst
WHERE
    te.parentTconst IN (
        SELECT
            tconst
        FROM
            title_basics
        WHERE
            primaryTitle = 'Game of Thrones'
    )
ORDER BY
    te.seasonNumber,
    te.episodeNumber;