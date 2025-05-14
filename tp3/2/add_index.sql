CREATE INDEX idx_title_basics_tconst_hash 
ON title_basics USING HASH (tconst);

CREATE INDEX idx_title_basics_tconst_btree
ON title_basics USING BTREE (tconst);
