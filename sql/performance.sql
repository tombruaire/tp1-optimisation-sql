-- 1. Analyse of table size
SELECT
    table_name,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as total_size,
    pg_size_pretty(pg_relation_size(quote_ident(table_name))) as table_size,
    pg_size_pretty(
        pg_total_relation_size(quote_ident(table_name)) - pg_relation_size(quote_ident(table_name))
    ) as index_size
FROM
    information_schema.tables
WHERE
    table_schema = 'public'
ORDER BY
    pg_total_relation_size(quote_ident(table_name)) DESC;

-- 2. Analyse of existing indexes
SELECT
    tablename,
    indexname,
    indexdef
FROM
    pg_indexes
WHERE
    schemaname = 'public'
ORDER BY
    tablename,
    indexname;

-- 3. Analyse of table statistics
SELECT
    relname as table_name,
    n_live_tup as row_count,
    n_dead_tup as dead_rows,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM
    pg_stat_user_tables
ORDER BY
    n_live_tup DESC;

-- 4. Analyse of sequence scans
SELECT
    relname as table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch
FROM
    pg_stat_user_tables
ORDER BY
    seq_scan DESC;

-- 5. Analyse of used indexes
SELECT
    schemaname,
    relname as table_name,
    indexrelname as index_name,
    idx_scan as number_of_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM
    pg_stat_user_indexes
ORDER BY
    idx_scan DESC;

-- 6. Analyse of expensive operations (requires pg_stat_statements)
-- Note: This query requires that the pg_stat_statements extension is enabled
-- SELECT
--     query,
--     calls,
--     total_time,
--     mean_time,
--     rows
-- FROM
--     pg_stat_statements
-- ORDER BY
--     mean_time DESC
-- LIMIT
--     10;
-- 7. Analyse of locks
SELECT
    locktype,
    relation :: regclass,
    mode,
    granted
FROM
    pg_locks
WHERE
    relation IS NOT NULL;

-- 8. Analyse of active connections
SELECT
    datname,
    usename,
    application_name,
    client_addr,
    backend_start,
    state,
    query
FROM
    pg_stat_activity
WHERE
    state != 'idle';