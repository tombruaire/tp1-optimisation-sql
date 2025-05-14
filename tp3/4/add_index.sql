-- Create a partial index on startyear for movies from the 2010s
CREATE INDEX idx_title_basics_movies_2010s ON title_basics(startyear)
WHERE startyear BETWEEN 2010 AND 2019 AND titletype = 'movie';

-- Create a complete index on startyear
CREATE INDEX idx_title_basics_startyear ON title_basics(startyear);