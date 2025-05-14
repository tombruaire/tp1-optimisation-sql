-- Create an index to optimize insensitive case searches
CREATE INDEX idx_title_basics_primarytitle_lower ON title_basics(LOWER(primarytitle));

-- Create an expression index for efficient decade searches
-- This extracts the decade from startyear (e.g., 1994 -> '199')
CREATE INDEX idx_title_basics_decade ON title_basics(SUBSTRING(CAST(startyear AS TEXT), 1, 3));