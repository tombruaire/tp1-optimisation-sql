-- Create an index on the startYear column
CREATE INDEX IF NOT EXISTS idx_title_basics_startyear ON title_basics(startyear);

-- Create an index on the genres column
CREATE INDEX IF NOT EXISTS idx_title_basics_genres ON title_basics(genres);

-- Create a composite index on the genres and startyear columns
CREATE INDEX IF NOT EXISTS idx_title_basics_genres_startyear ON title_basics(genres, startyear);

-- Create a composite index on the startyear and genres columns
CREATE INDEX IF NOT EXISTS idx_title_basics_startyear_genres ON title_basics(startyear, genres);