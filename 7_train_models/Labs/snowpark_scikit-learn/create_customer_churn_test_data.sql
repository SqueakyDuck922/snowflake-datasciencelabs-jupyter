-- =============================================================================
-- CREATE TEST DATA FOR: data_science_db.public.customer_churn
-- =============================================================================
--
-- PURPOSE:
--   This script creates a synthetic version of the Customer Churn dataset
--   required by the following notebooks:
--     - random_forest_classifier_snowpark.ipynb
--     - random_forest_classifier_snowpark_MINE.ipynb
--     - 7_train_models/Labs/snowpark_ml/01_snowpark_ml_feature_engineering.ipynb
--     - 7_train_models/Labs/snowpark_ml/02_snowpark_ml_training.ipynb
--     - 6_feature_engineering/Labs/feature_engineering/feature_engineering_python.ipynb
--
--   The original dataset is based on the well-known "Bank Customer Churn"
--   dataset (commonly found on Kaggle), adapted for "Snowbear Air" — an
--   airline. The key adaptation is MILEAGE_POINTS (airline mileage balance)
--   replacing the original BALANCE (bank account balance).
--
-- TABLE: data_science_db.public.customer_churn
--
-- COLUMNS (inferred from notebook code):
--   CUSTOMER_ID              INTEGER  - Unique customer identifier.
--                                       Dropped before model training.
--   SURNAME_MASKED           VARCHAR  - Masked customer surname (PII).
--                                       Dropped before model training.
--   CREDIT_SCORE             INTEGER  - Customer credit score.
--                                       Range: 350-850
--   GEOGRAPHY                VARCHAR  - Country: 'France', 'Spain', 'Germany'.
--                                       Distribution: ~50% France, ~25% Germany,
--                                       ~25% Spain.
--   GENDER                   VARCHAR  - 'Male' or 'Female'.
--                                       Distribution: ~55% Male, ~45% Female.
--   AGE                      INTEGER  - Customer age. Range: 18-92.
--                                       Mean ~39.
--   TENURE                   INTEGER  - Years as a customer. Range: 0-10.
--   MILEAGE_POINTS           FLOAT    - Airline mileage balance.
--                                       Range: 0-250,000.
--                                       ~30% of customers have 0 points.
--   NUM_OF_PRODUCTS          INTEGER  - Number of products held. Range: 1-4.
--                                       ~50% hold 1, ~46% hold 2, ~4% hold
--                                       3 or 4.
--   HAS_AIRLINE_CREDIT_CARD  INTEGER  - Whether customer holds an airline
--                                       credit card. 1=Yes, 0=No.
--                                       ~71% have one (value = 1).
--   IS_ACTIVE_MEMBER         INTEGER  - Whether customer is active.
--                                       1=Yes, 0=No. ~52% are active.
--   ESTIMATED_SALARY         FLOAT    - Estimated annual salary.
--                                       Range: $11,000-$200,000.
--   CHURNED                  INTEGER  - Target: 1=churned, 0=not churned.
--                                       ~20% churn rate.
--
-- ABOUT THE ORIGINAL DATASET:
--   - 10,000 rows
--   - Binary classification target (CHURNED = 0 or 1)
--   - Churn rate ~20% (class imbalance)
--   - Higher churn rates observed for:
--       * Customers in Germany
--       * Female customers
--       * Older customers (age > 40)
--       * Customers with 3 or more products
--       * Inactive members
--
-- THIS SYNTHETIC DATASET:
--   - 10,000 rows
--   - Uses Snowflake GENERATOR and HASH functions for reproducibility
--   - Mirrors the statistical properties and churn patterns above
--   - CHURNED is generated as a probability that depends on GEOGRAPHY,
--     GENDER, AGE, NUM_OF_PRODUCTS, and IS_ACTIVE_MEMBER, matching the
--     real dataset's known churn drivers
--
-- USAGE:
--   Run this entire script once in Snowflake (e.g. via Snowsight worksheets
--   or SnowSQL) before executing the customer churn notebooks.
-- =============================================================================


-- =============================================================================
-- STEP 1: Create database and schema (if not already present)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS data_science_db;
CREATE SCHEMA IF NOT EXISTS data_science_db.public;


-- =============================================================================
-- STEP 2: Create the customer_churn table
-- =============================================================================

CREATE OR REPLACE TABLE data_science_db.public.customer_churn (
    customer_id             INTEGER      NOT NULL,
    surname_masked          VARCHAR(50)  NOT NULL,
    credit_score            INTEGER      NOT NULL,
    geography               VARCHAR(20)  NOT NULL,
    gender                  VARCHAR(10)  NOT NULL,
    age                     INTEGER      NOT NULL,
    tenure                  INTEGER      NOT NULL,
    mileage_points          FLOAT        NOT NULL,
    num_of_products         INTEGER      NOT NULL,
    has_airline_credit_card INTEGER      NOT NULL,
    is_active_member        INTEGER      NOT NULL,
    estimated_salary        FLOAT        NOT NULL,
    churned                 INTEGER      NOT NULL
);


-- =============================================================================
-- STEP 3: Populate with synthetic data
-- =============================================================================
--
-- Design choices:
--   - 10,000 rows via TABLE(GENERATOR(ROWCOUNT => 10000))
--   - All random values use HASH() for full reproducibility
--   - GEOGRAPHY: France=0..4 (50%), Germany=5..6 (25%), Spain=7..9 (25%)
--   - GENDER: Male=0..4 (55%), Female=5-9 (45%)
--   - AGE: weighted toward 25-65, full range 18-92
--   - TENURE: uniform 0-10
--   - MILEAGE_POINTS: 30% zero, 70% uniform 1-250000
--   - NUM_OF_PRODUCTS: 50% one, 46% two, 3% three, 1% four
--   - HAS_AIRLINE_CREDIT_CARD: 1 (71%), 0 (29%)
--   - IS_ACTIVE_MEMBER: 1 (52%), 0 (48%)
--   - ESTIMATED_SALARY: uniform 11000-200000
--   - CREDIT_SCORE: uniform 350-850
--   - CHURNED: probability-based, driven by known churn factors:
--       * Germany: +15% churn probability
--       * Female: +8% churn probability
--       * Age > 40: +10% churn probability
--       * Num products >= 3: +25% churn probability
--       * Inactive member: +10% churn probability
--       * Base churn probability: 8%
--     Total probability capped ensuring overall ~20% churn rate.
--   - CUSTOMER_ID: sequential 1-10000
--   - SURNAME_MASKED: synthetic "Surname_XXXXXX" format
--
-- NOTE: Snowflake HASH() returns a signed 64-bit integer.
--       ABS(HASH(...)) / 9223372036854775807.0 maps to [0, 1].
--       MOD(ABS(HASH(...)), N) gives a uniform integer in [0, N-1].
-- =============================================================================

INSERT INTO data_science_db.public.customer_churn
WITH

-- Generate row numbers 1..10000
row_nums AS (
    SELECT seq4() + 1 AS rownum
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
),

-- Assign raw categorical values using hash-based bucketing
categoricals AS (
    SELECT
        rownum,

        -- GEOGRAPHY: 0-4 → France (~50%), 5-6 → Germany (~25%), 7-9 → Spain (~25%)
        CASE MOD(ABS(HASH(rownum, 1)), 10)
            WHEN 0 THEN 'France'
            WHEN 1 THEN 'France'
            WHEN 2 THEN 'France'
            WHEN 3 THEN 'France'
            WHEN 4 THEN 'France'
            WHEN 5 THEN 'Germany'
            WHEN 6 THEN 'Germany'
            WHEN 7 THEN 'Spain'
            WHEN 8 THEN 'Spain'
            ELSE        'Spain'
        END AS geography,

        -- GENDER: 0-5 → Male (~55%), 6-9 → Female (~45%)
        CASE WHEN MOD(ABS(HASH(rownum, 2)), 20) < 11 THEN 'Male' ELSE 'Female' END
            AS gender,

        -- AGE: base range 18-65 (90% of cases), with tail 66-92 (10%)
        -- This gives a realistic age distribution skewed toward working age
        CASE
            WHEN MOD(ABS(HASH(rownum, 3)), 10) < 9
            THEN 18 + MOD(ABS(HASH(rownum, 30)), 48)   -- 18-65
            ELSE  66 + MOD(ABS(HASH(rownum, 31)), 27)  -- 66-92
        END AS age,

        -- TENURE: uniform 0-10
        MOD(ABS(HASH(rownum, 4)), 11)::INTEGER AS tenure,

        -- MILEAGE_POINTS: 30% zero, 70% uniform 1-250000
        CASE
            WHEN MOD(ABS(HASH(rownum, 5)), 10) < 3 THEN 0.0
            ELSE ROUND(1.0 + ABS(HASH(rownum, 50)) / 9223372036854775807.0 * 249999.0, 2)
        END AS mileage_points,

        -- NUM_OF_PRODUCTS: 1=50%, 2=46%, 3=3%, 4=1%
        CASE MOD(ABS(HASH(rownum, 6)), 100)
            WHEN 97 THEN 4
            WHEN 98 THEN 4
            WHEN 99 THEN 3   -- 1% have 4 products
            ELSE
                CASE
                    WHEN MOD(ABS(HASH(rownum, 6)), 100) >= 97 THEN 3  -- already handled above
                    WHEN MOD(ABS(HASH(rownum, 6)), 100) >= 94 THEN 3  -- 3% have 3 products
                    WHEN MOD(ABS(HASH(rownum, 6)), 100) >= 48 THEN 2  -- 46% have 2 products
                    ELSE 1                                              -- 50% have 1 product
                END
        END AS num_of_products,

        -- HAS_AIRLINE_CREDIT_CARD: 1=has card (71%), 0=no card (29%)
        CASE WHEN MOD(ABS(HASH(rownum, 7)), 100) < 71 THEN 1 ELSE 0 END
            AS has_airline_credit_card,

        -- IS_ACTIVE_MEMBER: 1=active (52%), 0=inactive (48%)
        CASE WHEN MOD(ABS(HASH(rownum, 8)), 100) < 52 THEN 1 ELSE 0 END
            AS is_active_member,

        -- ESTIMATED_SALARY: uniform 11000-200000
        ROUND(11000.0 + ABS(HASH(rownum, 9)) / 9223372036854775807.0 * 189000.0, 2)
            AS estimated_salary,

        -- CREDIT_SCORE: uniform 350-850
        (350 + MOD(ABS(HASH(rownum, 10)), 501))::INTEGER AS credit_score

    FROM row_nums
),

-- Compute churn probability based on known churn drivers, then assign CHURNED
-- Base probability: 8%
-- Germany adds 15%, Female adds 8%, Age>40 adds 10%,
-- Products>=3 adds 25%, Inactive adds 10%
-- Max probability capped at 75% to avoid deterministic churn for all high-risk customers
-- The combination of these factors produces ~20% overall churn
churn_calc AS (
    SELECT
        rownum,
        geography,
        gender,
        age,
        tenure,
        mileage_points,
        num_of_products,
        has_airline_credit_card,
        is_active_member,
        estimated_salary,
        credit_score,

        -- Compute churn probability
        LEAST(0.75,
            0.08
            + CASE geography WHEN 'Germany' THEN 0.15 ELSE 0.0 END
            + CASE gender WHEN 'Female' THEN 0.08 ELSE 0.0 END
            + CASE WHEN age > 40 THEN 0.10 ELSE 0.0 END
            + CASE WHEN num_of_products >= 3 THEN 0.25 ELSE 0.0 END
            + CASE WHEN is_active_member = 0 THEN 0.10 ELSE 0.0 END
        ) AS churn_prob

    FROM categoricals
),

-- Apply the churn probability: if a random [0,1] hash < churn_prob → churned
final AS (
    SELECT
        rownum,
        geography,
        gender,
        age,
        tenure,
        mileage_points,
        num_of_products,
        has_airline_credit_card,
        is_active_member,
        estimated_salary,
        credit_score,
        CASE
            WHEN ABS(HASH(rownum, 99)) / 9223372036854775807.0 < churn_prob THEN 1
            ELSE 0
        END AS churned
    FROM churn_calc
)

SELECT
    f.rownum                    AS customer_id,

    -- Synthetic masked surname: 'Surname_' + 6-digit hash suffix
    CONCAT('Surname_', LPAD(TO_CHAR(MOD(ABS(HASH(f.rownum, 42)), 1000000)), 6, '0'))
                                AS surname_masked,

    f.credit_score              AS credit_score,
    f.geography                 AS geography,
    f.gender                    AS gender,
    f.age                       AS age,
    f.tenure                    AS tenure,
    f.mileage_points            AS mileage_points,
    f.num_of_products           AS num_of_products,
    f.has_airline_credit_card   AS has_airline_credit_card,
    f.is_active_member          AS is_active_member,
    f.estimated_salary          AS estimated_salary,
    f.churned                   AS churned

FROM final f
ORDER BY f.rownum;


-- =============================================================================
-- STEP 4: Verification queries
-- =============================================================================
-- Run these after the INSERT to confirm the data looks correct before running
-- the churn prediction notebooks.
-- =============================================================================

-- Total row count (expect 10,000)
SELECT COUNT(*) AS total_rows
FROM data_science_db.public.customer_churn;

-- Overall churn rate (expect approximately 20%)
SELECT
    ROUND(AVG(churned) * 100, 1) AS churn_rate_pct,
    SUM(churned)                  AS total_churned,
    COUNT(*) - SUM(churned)       AS total_not_churned
FROM data_science_db.public.customer_churn;

-- Geography distribution (expect France ~50%, Germany ~25%, Spain ~25%)
SELECT
    geography,
    COUNT(*)                                 AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM data_science_db.public.customer_churn
GROUP BY geography
ORDER BY count DESC;

-- Churn rate by geography (Germany should be highest)
SELECT
    geography,
    ROUND(AVG(churned) * 100, 1) AS churn_rate_pct
FROM data_science_db.public.customer_churn
GROUP BY geography
ORDER BY churn_rate_pct DESC;

-- Churn rate by gender (Female should be higher than Male)
SELECT
    gender,
    ROUND(AVG(churned) * 100, 1) AS churn_rate_pct
FROM data_science_db.public.customer_churn
GROUP BY gender
ORDER BY churn_rate_pct DESC;

-- Churn rate by number of products (3+ should be highest)
SELECT
    num_of_products,
    COUNT(*)                         AS count,
    ROUND(AVG(churned) * 100, 1)     AS churn_rate_pct
FROM data_science_db.public.customer_churn
GROUP BY num_of_products
ORDER BY num_of_products;

-- Churn rate by active member status (0=inactive should churn more than 1=active)
SELECT
    is_active_member,
    ROUND(AVG(churned) * 100, 1) AS churn_rate_pct
FROM data_science_db.public.customer_churn
GROUP BY is_active_member
ORDER BY is_active_member;

-- Summary statistics for numeric columns
SELECT
    ROUND(AVG(credit_score), 0)       AS avg_credit_score,
    ROUND(MIN(credit_score), 0)       AS min_credit_score,
    ROUND(MAX(credit_score), 0)       AS max_credit_score,
    ROUND(AVG(age), 1)                AS avg_age,
    ROUND(AVG(tenure), 1)             AS avg_tenure,
    ROUND(AVG(mileage_points), 0)     AS avg_mileage_points,
    ROUND(AVG(estimated_salary), 0)   AS avg_estimated_salary
FROM data_science_db.public.customer_churn;

-- Sample a few rows to visually inspect
SELECT *
FROM data_science_db.public.customer_churn
LIMIT 10;
