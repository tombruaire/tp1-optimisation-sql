-- Import title_basics
COPY title_basics
FROM
    PROGRAM 'zcat /import/title.basics.tsv.gz' WITH (
        FORMAT csv,
        DELIMITER E'\t',
        HEADER,
        NULL '\N',
        QUOTE E'\001'
    );

-- Import title_akas
COPY title_akas
FROM
    PROGRAM 'zcat /import/title.akas.tsv.gz' WITH (
        FORMAT csv,
        DELIMITER E'\t',
        HEADER,
        NULL '\N',
        QUOTE E'\001'
    );

-- Import title_crew
COPY title_crew
FROM
    PROGRAM 'zcat /import/title.crew.tsv.gz' WITH (
        FORMAT csv,
        DELIMITER E'\t',
        HEADER,
        NULL '\N',
        QUOTE E'\001'
    );

-- Import title_episode
COPY title_episode
FROM
    PROGRAM 'zcat /import/title.episode.tsv.gz' WITH (
        FORMAT csv,
        DELIMITER E'\t',
        HEADER,
        NULL '\N',
        QUOTE E'\001'
    );

-- Import title_principals
COPY title_principals
FROM
    PROGRAM 'zcat /import/title.principals.tsv.gz' WITH (
        FORMAT csv,
        DELIMITER E'\t',
        HEADER,
        NULL '\N',
        QUOTE E'\001'
    );

-- Import title_ratings
COPY title_ratings
FROM
    PROGRAM 'zcat /import/title.ratings.tsv.gz' WITH (
        FORMAT csv,
        DELIMITER E'\t',
        HEADER,
        NULL '\N',
        QUOTE E'\001'
    );

-- Import name_basics
COPY name_basics
FROM
    PROGRAM 'zcat /import/name.basics.tsv.gz' WITH (
        FORMAT csv,
        DELIMITER E'\t',
        HEADER,
        NULL '\N',
        QUOTE E'\001'
    );