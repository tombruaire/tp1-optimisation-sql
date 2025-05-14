-- Create a standard index on the filtering column
CREATE INDEX idx_title_basics_genres ON title_basics(genres);

-- Create a covering index to include the columns needed for the query
CREATE INDEX idx_title_basics_covering ON title_basics(startyear) INCLUDE (primarytitle, genres);
