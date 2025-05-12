CREATE TABLE IF NOT EXISTS title_basics (
    tconst VARCHAR(12) PRIMARY KEY,
    titleType VARCHAR(20),
    primaryTitle VARCHAR(500),
    originalTitle VARCHAR(500),
    isAdult BOOLEAN,
    startYear INTEGER,
    endYear INTEGER,
    runtimeMinutes INTEGER,
    genres VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS title_akas (
    titleId VARCHAR(12),
    ordering INTEGER,
    title TEXT,
    region VARCHAR(4),
    language VARCHAR(3),
    types VARCHAR(100),
    attributes VARCHAR(100),
    isOriginalTitle BOOLEAN,
    PRIMARY KEY (titleId, ordering)
    -- FOREIGN KEY (titleId) REFERENCES title_basics(tconst)
);

CREATE TABLE IF NOT EXISTS title_crew (
    tconst VARCHAR(12) PRIMARY KEY,
    directors TEXT,
    writers TEXT
    -- FOREIGN KEY (tconst) REFERENCES title_basics(tconst)
);

CREATE TABLE IF NOT EXISTS title_episode (
    tconst VARCHAR(12) PRIMARY KEY,
    parentTconst VARCHAR(12),
    seasonNumber INTEGER,
    episodeNumber INTEGER
    -- FOREIGN KEY (tconst) REFERENCES title_basics(tconst),
    -- FOREIGN KEY (parentTconst) REFERENCES title_basics(tconst)
);

CREATE TABLE IF NOT EXISTS title_principals (
    tconst VARCHAR(12),
    ordering INTEGER,
    nconst VARCHAR(12),
    category VARCHAR(50),
    job TEXT,
    characters TEXT,
    PRIMARY KEY (tconst, ordering)
    -- FOREIGN KEY (tconst) REFERENCES title_basics(tconst)
);

CREATE TABLE IF NOT EXISTS title_ratings (
    tconst VARCHAR(12) PRIMARY KEY,
    averageRating DECIMAL(3, 1),
    numVotes INTEGER
    -- FOREIGN KEY (tconst) REFERENCES title_basics(tconst)
);

CREATE TABLE IF NOT EXISTS name_basics (
    nconst VARCHAR(12) PRIMARY KEY,
    primaryName VARCHAR(200),
    birthYear INTEGER,
    deathYear INTEGER,
    primaryProfession TEXT,
    knownForTitles TEXT
);