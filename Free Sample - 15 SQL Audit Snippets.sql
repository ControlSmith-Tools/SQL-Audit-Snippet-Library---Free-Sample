/*
  LS-004 — SQL Audit Snippet and Pattern Library — FREE SAMPLE
  ============================================================
  15 snippets covering all 7 categories of the full 100-snippet pack.
  Platform: SQL Server 2016+

  This sample is free to use with attribution. The full pack adds 85
  more snippets, an Examples Workbook, an Adaptation Prompt Sheet,
  PostgreSQL equivalents, and a SQL Server sample database.

  -> See the main product listing for the full pack.

  DISCLAIMER: Reference material only. Not legal, audit, or certification advice.
*/
GO

-- ###########################################################
-- CATEGORY: VALIDATION
-- ###########################################################
GO

-- ============================================================
-- SNIPPET: VAL-001 — Row Count Check
-- PURPOSE: Verify actual row count matches expected count.
-- ADAPT:   [schema].[table], @expected
-- OUTPUT:  actual_count | expected_count | variance | status
-- PITFALL: Soft-deleted rows are counted unless filtered with WHERE is_deleted = 0.
-- ============================================================
DECLARE @expected BIGINT = 10000; -- ADAPT: set expected row count

SELECT
    COUNT_BIG(*)                          AS actual_count,
    @expected                             AS expected_count,
    COUNT_BIG(*) - @expected              AS variance,
    CASE WHEN COUNT_BIG(*) = @expected
         THEN 'PASS' ELSE 'FAIL' END      AS status
FROM [schema].[table]; -- ADAPT
GO

-- ============================================================
-- SNIPPET: VAL-003 — Referential Integrity Check
-- PURPOSE: Find child rows with no matching parent record.
-- ADAPT:   [child_schema].[child_table], child_fk_col, [parent_schema].[parent_table], parent_pk_col
-- OUTPUT:  orphan_count | sample_orphan_ids
-- PITFALL: Soft-deleted parents may create false positives; exclude deleted parents if needed.
-- ============================================================
SELECT
    COUNT(*)                              AS orphan_count,
    STRING_AGG(CAST(c.id AS VARCHAR(50)), ', ') AS sample_ids
FROM [child_schema].[child_table] c     -- ADAPT
WHERE NOT EXISTS (
    SELECT 1
    FROM [parent_schema].[parent_table] p -- ADAPT
    WHERE p.id = c.parent_id             -- ADAPT: match column names
);
GO

-- ###########################################################
-- CATEGORY: RECONCILIATION
-- ###########################################################
GO

-- ============================================================
-- SNIPPET: REC-001 — Period-over-Period Variance
-- PURPOSE: Calculate and flag period-to-period amount changes.
-- ADAPT:   [schema].[table], amount_col, period_col, @threshold_pct
-- OUTPUT:  period | amount | prior_amount | change | pct_change | flag
-- PITFALL: `c.period_col - 1` only works for integer-sortable periods. For
--          'YYYY-MM' text periods, replace with a date-based prior-period join.
-- ============================================================
DECLARE @threshold DECIMAL(5,2) = 10.0; -- ADAPT: % threshold for flagging

WITH period_totals AS (
    SELECT
        period_col,                       -- ADAPT
        SUM(amount_col) AS total          -- ADAPT
    FROM [schema].[table]                 -- ADAPT
    GROUP BY period_col
)
SELECT
    c.period_col         AS period,
    c.total              AS current_amount,
    p.total              AS prior_amount,
    c.total - p.total    AS change_amount,
    CAST(100.0 * (c.total - p.total) / NULLIF(p.total, 0) AS DECIMAL(8,2)) AS pct_change,
    CASE WHEN ABS(100.0 * (c.total - p.total) / NULLIF(p.total, 0)) > @threshold
         THEN 'REVIEW' ELSE 'OK' END AS flag
FROM period_totals c
LEFT JOIN period_totals p ON p.period_col = c.period_col - 1 -- ADAPT: period arithmetic
ORDER BY c.period_col DESC;
GO

-- ============================================================
-- SNIPPET: REC-005 — Unmatched Records (Full Outer Join Diff)
-- PURPOSE: Find rows present in one source but missing from the other.
-- ADAPT:   Both tables, join key column(s)
-- OUTPUT:  key_value | in_a | in_b | note
-- PITFALL: Joining on a non-unique key produces phantom mismatches (one-to-many
--          fanout). Confirm the key is unique on both sides before relying on
--          the in_a / in_b flags.
-- ============================================================
SELECT
    COALESCE(a.key_col, b.key_col) AS key_value, -- ADAPT
    CASE WHEN a.key_col IS NOT NULL THEN 'YES' ELSE 'NO' END AS in_source_a,
    CASE WHEN b.key_col IS NOT NULL THEN 'YES' ELSE 'NO' END AS in_source_b,
    CASE
        WHEN a.key_col IS NULL THEN 'Only in Source B'
        WHEN b.key_col IS NULL THEN 'Only in Source A'
    END AS note
FROM [schema_a].[table_a] a              -- ADAPT
FULL OUTER JOIN [schema_b].[table_b] b   -- ADAPT
    ON a.key_col = b.key_col             -- ADAPT
WHERE a.key_col IS NULL OR b.key_col IS NULL;
GO

-- ###########################################################
-- CATEGORY: DEDUPLICATION
-- ###########################################################
GO

-- ============================================================
-- SNIPPET: DUP-001 — Exact Duplicate Rows
-- PURPOSE: Find completely identical rows in a table.
-- ADAPT:   [schema].[table], list all columns in SELECT and GROUP BY
-- OUTPUT:  col1 | col2 | ... | duplicate_count
-- PITFALL: Large tables need TOP N or date filter to avoid timeout.
-- ============================================================
SELECT
    col1, col2, col3,                     -- ADAPT: all columns that define a duplicate
    COUNT(*) AS duplicate_count
FROM [schema].[table]                     -- ADAPT
GROUP BY col1, col2, col3                 -- ADAPT
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
GO

-- ============================================================
-- SNIPPET: DUP-006 — Duplicate Invoice Numbers
-- PURPOSE: Find duplicate invoice numbers (should be globally unique).
-- ADAPT:   [schema].[table], invoice_number_col
-- OUTPUT:  invoice_number | count | suppliers | dates
-- PITFALL: Some systems reuse invoice numbers across suppliers — if `distinct_suppliers`
--          > 1, the duplication may be by design rather than an error.
-- ============================================================
SELECT
    invoice_number,                       -- ADAPT
    COUNT(*) AS occurrence_count,
    COUNT(DISTINCT supplier_id) AS distinct_suppliers, -- ADAPT
    MIN(invoice_date) AS first_date,      -- ADAPT
    MAX(invoice_date) AS last_date        -- ADAPT
FROM [schema].[invoices]                  -- ADAPT
GROUP BY invoice_number                   -- ADAPT
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;
GO

-- ###########################################################
-- CATEGORY: EXCEPTION DETECTION
-- ###########################################################
GO

-- ============================================================
-- SNIPPET: EXC-001 — Values Above Threshold
-- PURPOSE: Flag transactions exceeding an approval or control limit.
-- ADAPT:   [schema].[table], amount_col, @threshold
-- OUTPUT:  id | amount | exceeded_by | approver (if available)
-- PITFALL: Confirm the threshold matches the actual control limit in policy —
--          stale or default values produce misleading findings.
-- ============================================================
DECLARE @threshold DECIMAL(18,2) = 5000.00; -- ADAPT

SELECT
    id,                                   -- ADAPT
    amount_col,                           -- ADAPT
    amount_col - @threshold AS exceeded_by,
    approver_col                          -- ADAPT (NULL if no approver column)
FROM [schema].[table]                     -- ADAPT
WHERE amount_col > @threshold
ORDER BY amount_col DESC;
GO

-- ============================================================
-- SNIPPET: EXC-005 — Transactions Just Below Approval Limit
-- PURPOSE: Detect potential limit circumvention (just-below-limit clustering).
-- ADAPT:   [schema].[table], amount_col, @limit, @buffer
-- OUTPUT:  id | amount | distance_below_limit | user_id
-- PITFALL: Confirm approval limit with finance policy before setting @limit.
-- ============================================================
DECLARE @limit  DECIMAL(18,2) = 5000.00; -- ADAPT: approval limit
DECLARE @buffer DECIMAL(18,2) = 250.00;  -- ADAPT: how far below the limit to flag

SELECT
    id,                                   -- ADAPT
    amount_col,                           -- ADAPT
    @limit - amount_col AS distance_below_limit,
    user_id,                              -- ADAPT (if available)
    created_at                            -- ADAPT
FROM [schema].[table]                     -- ADAPT
WHERE amount_col BETWEEN (@limit - @buffer) AND (@limit - 0.01)
ORDER BY amount_col DESC;
GO

-- ============================================================
-- SNIPPET: EXC-013 — Weekend/Holiday Transactions
-- PURPOSE: Flag transactions on weekends (adjust for public holidays manually).
-- ADAPT:   [schema].[table], timestamp_col
-- OUTPUT:  id | transaction_date | day_of_week | amount
-- PITFALL: DATEPART(WEEKDAY, ...) depends on @@DATEFIRST. Set explicitly with
--          `SET DATEFIRST 7;` (Sunday-first) before running, or use DATENAME for
--          locale-safe comparison.
-- ============================================================
SELECT
    id,                                   -- ADAPT
    CAST(transaction_date AS DATE) AS trans_date, -- ADAPT
    DATENAME(WEEKDAY, transaction_date) AS day_of_week,
    amount_col                            -- ADAPT
FROM [schema].[table]                     -- ADAPT
WHERE DATEPART(WEEKDAY, transaction_date) IN (1, 7) -- 1=Sunday, 7=Saturday
ORDER BY transaction_date DESC;
GO

-- ###########################################################
-- CATEGORY: DATE CONTROLS
-- ###########################################################
GO

-- ============================================================
-- SNIPPET: DAT-001 — Future Dates
-- PURPOSE: Find records with dates beyond today (data entry errors).
-- ADAPT:   [schema].[table], date_col
-- OUTPUT:  id | date_value | days_in_future
-- PITFALL: Future-dated records may be valid (forward contracts, scheduled events).
-- ============================================================
SELECT
    id,                                   -- ADAPT
    date_col,                             -- ADAPT
    DATEDIFF(DAY, GETDATE(), date_col) AS days_in_future
FROM [schema].[table]                     -- ADAPT
WHERE date_col > GETDATE()
ORDER BY date_col ASC;
GO

-- ============================================================
-- SNIPPET: DAT-003 — Date Sequence Gaps
-- PURPOSE: Find gaps in a date sequence (missing days/months).
-- ADAPT:   [schema].[table], date_col, period granularity
-- OUTPUT:  gap_date | preceding_date | following_date
-- PITFALL: Business-day-only sequences legitimately have weekend gaps.
-- ============================================================
WITH date_series AS (
    SELECT CAST(date_col AS DATE) AS d,
           LEAD(CAST(date_col AS DATE)) OVER (ORDER BY date_col) AS next_d
    FROM [schema].[table]                 -- ADAPT
),
gaps AS (
    SELECT d, next_d, DATEDIFF(DAY, d, next_d) - 1 AS gap_days
    FROM date_series
    WHERE DATEDIFF(DAY, d, next_d) > 1
)
SELECT
    d AS preceding_date,
    next_d AS following_date,
    gap_days
FROM gaps
ORDER BY d;
GO

-- ###########################################################
-- CATEGORY: MAPPING CHECKS
-- ###########################################################
GO

-- ============================================================
-- SNIPPET: MAP-001 — Orphaned Foreign Keys
-- PURPOSE: Find child records with no matching parent (broken FK relationship).
-- ADAPT:   [child_schema].[child_table], child_fk_col, [parent_schema].[parent], parent_pk
-- OUTPUT:  orphan_count | sample_ids
-- PITFALL: Soft-deleted parents (where the parent row still exists but has
--          `deleted_at IS NOT NULL`) won't appear as orphans here; add a filter
--          to the parent table if your soft-delete semantics require it.
-- ============================================================
SELECT
    COUNT(*) AS orphan_count,
    STRING_AGG(CAST(c.id AS VARCHAR(20)), ', ') AS sample_orphan_ids
FROM [schema].[child_table] c             -- ADAPT
WHERE NOT EXISTS (
    SELECT 1 FROM [schema].[parent_table] p -- ADAPT
    WHERE p.id = c.parent_id              -- ADAPT
);
GO

-- ============================================================
-- SNIPPET: MAP-002 — Invalid Category Codes
-- PURPOSE: Find records using codes not in the approved reference table.
-- ADAPT:   [schema].[transactions], code_col, [schema].[code_reference], valid_code_col
-- OUTPUT:  invalid_code | occurrence_count
-- PITFALL: Newly-added codes might not yet exist in the lookup — coordinate with
--          data owners before flagging as exceptions.
-- ============================================================
SELECT
    t.code_col AS invalid_code,           -- ADAPT
    COUNT(*) AS occurrence_count
FROM [schema].[transactions] t            -- ADAPT
LEFT JOIN [schema].[code_reference] r     -- ADAPT
    ON r.valid_code = t.code_col          -- ADAPT
WHERE r.valid_code IS NULL
  AND t.code_col IS NOT NULL
GROUP BY t.code_col
ORDER BY occurrence_count DESC;
GO

-- ###########################################################
-- CATEGORY: EVIDENCE EXPORTS
-- ###########################################################
GO

-- ============================================================
-- SNIPPET: EVD-001 — Formatted Audit Evidence Extract
-- PURPOSE: Produce a standardised evidence extract with metadata.
-- ADAPT:   [schema].[table], relevant columns, period filter
-- OUTPUT:  evidence_id | period | description | count | status | extracted_at
-- PITFALL: SYSTEM_USER returns the login the query ran under — confirm this is
--          the auditor identity, not a service account, before treating it as
--          provenance evidence.
-- ============================================================
SELECT
    NEWID()                               AS evidence_id,
    '2026-Q1'                             AS audit_period, -- ADAPT
    'Access Review — All Database Users'  AS evidence_description, -- ADAPT
    COUNT(*)                              AS record_count,
    'Extracted'                           AS status,
    GETDATE()                             AS extracted_at,
    SYSTEM_USER                           AS extracted_by
FROM [schema].[table];                    -- ADAPT: your evidence query
GO

-- ============================================================
-- SNIPPET: EVD-008 — Random Sample Selection
-- PURPOSE: Select a random sample from a population for control testing.
-- ADAPT:   [schema].[table], @sample_size
-- OUTPUT:  sampled records in random order
-- PITFALL: NEWID() draws a fresh sample on every run; if you need reproducibility
--          (e.g. for a peer-reviewed workpaper) capture the sampled IDs into a
--          fixed table instead of re-running the query.
-- ============================================================
DECLARE @sample_size INT = 25;            -- ADAPT: required sample size

SELECT TOP (@sample_size)
    id,                                   -- ADAPT
    relevant_field_1,                     -- ADAPT
    relevant_field_2,                     -- ADAPT
    created_at                            -- ADAPT
FROM [schema].[table]                     -- ADAPT
WHERE status_col = 'Active'               -- ADAPT
ORDER BY NEWID();                         -- Random ordering


/* ============================================================
   Want the other 85 snippets?
   ============================================================
   The full LS-004 pack includes:
     - 100 SQL Server snippets across the 7 categories above
     - 100 PostgreSQL equivalents
     - Snippet Index (markdown)
     - Examples Workbook with input/output samples
     - Adaptation Prompt Sheet (10 AI prompt templates)
     - SQL Server sample database (CREATE + seed)

   See the main product listing for purchase.
   ============================================================ */
