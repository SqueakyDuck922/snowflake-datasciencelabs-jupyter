-- =============================================================================
-- CREATE TEST DATA FOR: data_science_db.new_data.customers
-- =============================================================================
--
-- PURPOSE:
--   This script creates synthetic "new customer" data for batch scoring,
--   required by:
--     - 02_batch_scoring.py
--
--   The table represents customers whose churn has NOT yet been observed —
--   i.e. the model from 01_train_model_for_batch.py is used to predict
--   whether they will churn.
--
-- RELATIONSHIP TO customer_churn TABLE:
--   This table has exactly the same columns as data_science_db.public.customer_churn
--   EXCEPT there is no CHURNED column (that is the target we are predicting).
--   The feature engineering in 02_batch_scoring.py is identical to 01_train_model_for_batch.py:
--     - Drop CUSTOMER_ID and SURNAME_MASKED
--     - Convert TENURE, NUM_OF_PRODUCTS, MILEAGE_POINTS, ESTIMATED_SALARY to numeric
--     - pd.get_dummies() to one-hot encode GEOGRAPHY and GENDER
--
-- CRITICAL CONSTRAINT:
--   pd.get_dummies() only creates dummy columns for categories that APPEAR in
--   the data. If any of the 3 GEOGRAPHY values or 2 GENDER values are absent,
--   the resulting feature matrix will not match the trained model's expected
--   columns, and model.predict() will fail.
--
--   This script guarantees all categories are present by:
--   1. Inserting 6 "seed" rows (one per GEOGRAPHY × GENDER combination)
--   2. Then generating the remaining ~994 rows randomly
--
-- TABLE: data_science_db.new_data.customers
--
-- COLUMNS:
--   CUSTOMER_ID              INTEGER  - Unique identifier. Retained to join
--                                       predictions back. Not used in model.
--   SURNAME_MASKED           VARCHAR  - Masked PII, dropped before modelling.
--   CREDIT_SCORE             INTEGER  - Range: 350-850
--   GEOGRAPHY                VARCHAR  - 'France', 'Spain', or 'Germany'
--   GENDER                   VARCHAR  - 'Male' or 'Female'
--   AGE                      INTEGER  - Range: 18-92
--   TENURE                   INTEGER  - Years as customer, 0-10
--   MILEAGE_POINTS           FLOAT    - Airline mileage balance, 0-250000
--   NUM_OF_PRODUCTS          INTEGER  - 1-4
--   HAS_AIRLINE_CREDIT_CARD  INTEGER  - 1=Yes, 0=No
--   IS_ACTIVE_MEMBER         INTEGER  - 1=Yes, 0=No
--   ESTIMATED_SALARY         FLOAT    - $11,000-$200,000
--
-- NOTE: CHURNED is intentionally absent — it is the prediction target.
--
-- USAGE:
--   Run this script once in Snowflake (Snowsight or SnowSQL) before running
--   02_batch_scoring.py.
-- =============================================================================


-- =============================================================================
-- STEP 1: Create database, schema, and table
-- =============================================================================

CREATE DATABASE IF NOT EXISTS data_science_db;
CREATE SCHEMA IF NOT EXISTS data_science_db.new_data;

CREATE OR REPLACE TABLE data_science_db.new_data.customers (
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
    estimated_salary        FLOAT        NOT NULL
);


-- =============================================================================
-- STEP 2: Insert 6 guaranteed-coverage seed rows
--
-- One row per GEOGRAPHY × GENDER combination ensures pd.get_dummies() sees all
-- categories and produces the same 5 dummy columns as the training data:
--   GEOGRAPHY_France, GEOGRAPHY_Germany, GEOGRAPHY_Spain, GENDER_Female, GENDER_Male
-- These use customer_id values 1-6 to avoid collision with the generated data.
-- =============================================================================

INSERT INTO data_science_db.new_data.customers VALUES
-- France Female
(1,  'Surname_000001', 680, 'France',  'Female', 35, 5, 45000.00, 1, 1, 1, 85000.00),
-- France Male
(2,  'Surname_000002', 720, 'France',  'Male',   42, 7, 82000.00, 2, 1, 0, 120000.00),
-- Germany Female
(3,  'Surname_000003', 590, 'Germany', 'Female', 55, 3, 0.00,     1, 0, 0, 65000.00),
-- Germany Male
(4,  'Surname_000004', 640, 'Germany', 'Male',   38, 8, 120500.00,2, 1, 1, 95000.00),
-- Spain Female
(5,  'Surname_000005', 750, 'Spain',   'Female', 28, 2, 15000.00, 1, 1, 1, 140000.00),
-- Spain Male
(6,  'Surname_000006', 610, 'Spain',   'Male',   47, 6, 60000.00, 1, 0, 0, 72000.00);


-- =============================================================================
-- STEP 3: Generate remaining ~994 rows (customer_id 7 to 1000)
--
-- Same distributions as data_science_db.public.customer_churn but using
-- different hash seed values (200-series) to produce distinct data.
-- =============================================================================

INSERT INTO data_science_db.new_data.customers
WITH

row_nums AS (
    SELECT seq4() + 7 AS rownum
    FROM TABLE(GENERATOR(ROWCOUNT => 994))
),

customers AS (
    SELECT
        rownum AS customer_id,

        -- SURNAME_MASKED: 'Surname_' + 6-digit padded suffix
        CONCAT('Surname_', LPAD(TO_CHAR(MOD(ABS(HASH(rownum, 242)), 1000000)), 6, '0'))
            AS surname_masked,

        -- CREDIT_SCORE: uniform 350-850
        (350 + MOD(ABS(HASH(rownum, 210)), 501))::INTEGER
            AS credit_score,

        -- GEOGRAPHY: France ~50%, Germany ~25%, Spain ~25%
        CASE MOD(ABS(HASH(rownum, 201)), 10)
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

        -- GENDER: Male ~55%, Female ~45%
        CASE WHEN MOD(ABS(HASH(rownum, 202)), 20) < 11 THEN 'Male' ELSE 'Female' END
            AS gender,

        -- AGE: 90% range 18-65, 10% range 66-92
        CASE
            WHEN MOD(ABS(HASH(rownum, 203)), 10) < 9
            THEN 18 + MOD(ABS(HASH(rownum, 230)), 48)
            ELSE 66 + MOD(ABS(HASH(rownum, 231)), 27)
        END AS age,

        -- TENURE: uniform 0-10
        MOD(ABS(HASH(rownum, 204)), 11)::INTEGER AS tenure,

        -- MILEAGE_POINTS: 30% zero, 70% uniform 1-250000
        CASE
            WHEN MOD(ABS(HASH(rownum, 205)), 10) < 3 THEN 0.0
            ELSE ROUND(1.0 + ABS(HASH(rownum, 250)) / 9223372036854775807.0 * 249999.0, 2)
        END AS mileage_points,

        -- NUM_OF_PRODUCTS: 1=50%, 2=46%, 3=3%, 4=1%
        CASE
            WHEN MOD(ABS(HASH(rownum, 206)), 100) >= 99 THEN 4
            WHEN MOD(ABS(HASH(rownum, 206)), 100) >= 96 THEN 3
            WHEN MOD(ABS(HASH(rownum, 206)), 100) >= 50 THEN 2
            ELSE 1
        END AS num_of_products,

        -- HAS_AIRLINE_CREDIT_CARD: 1=71%, 0=29%
        CASE WHEN MOD(ABS(HASH(rownum, 207)), 100) < 71 THEN 1 ELSE 0 END
            AS has_airline_credit_card,

        -- IS_ACTIVE_MEMBER: 1=52%, 0=48%
        CASE WHEN MOD(ABS(HASH(rownum, 208)), 100) < 52 THEN 1 ELSE 0 END
            AS is_active_member,

        -- ESTIMATED_SALARY: uniform 11000-200000
        ROUND(11000.0 + ABS(HASH(rownum, 209)) / 9223372036854775807.0 * 189000.0, 2)
            AS estimated_salary

    FROM row_nums
)

SELECT * FROM customers
ORDER BY customer_id;


-- =============================================================================
-- STEP 4: Verification queries
-- =============================================================================

-- Row count (expect 1,000)
SELECT COUNT(*) AS total_rows
FROM data_science_db.new_data.customers;

-- Confirm all 3 geography values and both gender values are present
-- (critical for pd.get_dummies() to produce the correct dummy columns)
SELECT geography, gender, COUNT(*) AS count
FROM data_science_db.new_data.customers
GROUP BY geography, gender
ORDER BY geography, gender;

-- Confirm there is NO churned column (the table should only have 12 columns)
-- This query lists all columns:
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'NEW_DATA'
  AND table_name   = 'CUSTOMERS'
  AND table_catalog = 'DATA_SCIENCE_DB'
ORDER BY ordinal_position;

-- Sample a few rows
SELECT * FROM data_science_db.new_data.customers LIMIT 10;
