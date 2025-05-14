-- 1. LIKE with index - no index to create, using the existing query

-- 2. LIKE with standard B-tree index
CREATE INDEX idx_title_basics_primarytitle ON title_basics(primarytitle);

-- 3. Index trigram (GIN) - requires the pg_trgm extension
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_title_basics_primarytitle_trgm ON title_basics USING GIN (primarytitle gin_trgm_ops);

-- 4. Full-text search index
-- Create GIN index for full-text search on primaryTitle
CREATE INDEX idx_title_basics_primarytitle_fts ON title_basics 
USING GIN (to_tsvector('english', primarytitle));

-- Dropping indexes to clean up
-- DROP INDEX idx_title_basics_primarytitle;
-- DROP INDEX idx_title_basics_primarytitle_trgm;
-- DROP INDEX idx_title_basics_primarytitle_fts;
