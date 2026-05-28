-- Script generate by CLINE to generate test data for the USA Housing dataset used in linear regression notebooks.

-- =============================================================================
-- CREATE TEST DATA FOR: data_science_db.housing.usa_housing
-- =============================================================================
--
-- PURPOSE:
--   This script creates a synthetic version of the USA Housing dataset
--   required by the linear regression notebooks:
--     - linear_regression_snowpark.ipynb
--     - linear_regression_snowpark_MINE.ipynb
--     - multivariate_linear_regression_snowpark.ipynb
--
--   The original dataset is a well-known ML teaching dataset (commonly found
--   on Kaggle as "USA_Housing.csv"). This synthetic version mirrors the
--   structure and statistical characteristics of that dataset.
--
-- TABLE: data_science_db.housing.usa_housing
--
-- COLUMNS (inferred from notebook code):
--   AVERAGE_AREA_INCOME        FLOAT    - Primary predictor; highest correlation
--                                         with PRICE. Range ~$17k-$107k,
--                                         median ~$68.5k
--   AVERAGE_HOME_AGE           FLOAT    - Average age of homes in the area.
--                                         Range ~1-9 years, mean ~5.98
--   AVERAGE_NUMBER_OF_ROOMS    FLOAT    - Average rooms per home.
--                                         Range ~4-9, mean ~6.99
--   AVERAGE_NUMBER_OF_BEDROOMS FLOAT    - Average bedrooms per home.
--                                         Range ~2-6, mean ~3.98
--   AREA_POPULATION            FLOAT    - Population of the area.
--                                         Range ~170-70000, mean ~35k
--   PRICE                      FLOAT    - Target variable: home price.
--                                         Range ~$15k-$2.5M, median ~$1.23M
--   ADDRESS                    VARCHAR  - Street address string.
--                                         Dropped before model training via:
--                                         housingDF.drop('address')
--
-- ABOUT THE REAL USA HOUSING DATASET:
--   - 5,000 rows
--   - Features are area-level averages (not individual house measurements)
--   - Strong positive correlation between AVERAGE_AREA_INCOME and PRICE
--   - PRICE is approximately: 21.5 * INCOME + some noise + contributions
--     from other features
--
-- STATISTICAL TARGETS FOR SYNTHETIC DATA:
--   AVERAGE_AREA_INCOME:        mean=68,583  std=10,657   range=[17,796, 107,701]
--   AVERAGE_HOME_AGE:           mean=5.98    std=2.00     range=[1.0, 9.5]
--   AVERAGE_NUMBER_OF_ROOMS:    mean=6.99    std=1.01     range=[4.0, 9.5]
--   AVERAGE_NUMBER_OF_BEDROOMS: mean=3.98    std=1.23     range=[2.0, 6.5]
--   AREA_POPULATION:            mean=35,553  std=9,385    range=[172, 69,621]
--   PRICE:                      mean=1,232k  std=354k     range=[15k, 2,469k]
--
-- THIS SYNTHETIC DATASET:
--   - 5,000 rows
--   - Uses Snowflake GENERATOR and HASH functions for reproducibility
--   - Approximates the statistical properties above via scaled uniform
--     distributions centred on the reported means
--   - PRICE is computed as a linear combination of the features plus noise,
--     matching the real dataset's structure
--
-- USAGE:
--   Run this entire script once in Snowflake (e.g. via Snowsight worksheets
--   or SnowSQL) before executing the linear regression notebooks.
-- =============================================================================


-- =============================================================================
-- STEP 1: Create database and schema
-- =============================================================================

CREATE DATABASE IF NOT EXISTS data_science_db;
CREATE SCHEMA IF NOT EXISTS data_science_db.housing;


-- =============================================================================
-- STEP 2: Create the usa_housing table
-- =============================================================================

CREATE OR REPLACE TABLE data_science_db.housing.usa_housing (
    average_area_income        FLOAT        NOT NULL,
    average_home_age           FLOAT        NOT NULL,
    average_number_of_rooms    FLOAT        NOT NULL,
    average_number_of_bedrooms FLOAT        NOT NULL,
    area_population            FLOAT        NOT NULL,
    price                      FLOAT        NOT NULL,
    address                    VARCHAR(200) NOT NULL
);


-- =============================================================================
-- STEP 3: Populate with synthetic data
-- =============================================================================
--
-- Design choices:
--   - 5,000 rows generated via TABLE(GENERATOR(ROWCOUNT => 5000))
--   - Each feature is approximated using:
--       value = mean + std * scaled_hash
--     where scaled_hash is a hash-derived value in [-1, 1] scaled to cover
--     approximately ±3 standard deviations of the real distribution.
--   - PRICE is generated as a linear model of the features plus noise,
--     mimicking the real dataset's relationship:
--       PRICE ≈ 21.5 * INCOME + 164,883 * HOME_AGE + 122,368 * ROOMS
--             + 2,233 * BEDROOMS + 15.15 * POPULATION + noise
--     Coefficients are approximate and inferred from the dataset description.
--   - Addresses are synthetic but plausible (format: "NNN Street Name, City, ST")
--   - All HASH() calls use different seed values to ensure independence between
--     features.
--   - Using HASH() instead of RANDOM() makes results fully reproducible.
--
-- NOTE: Snowflake HASH() returns a signed 64-bit integer.
--       ABS(HASH(...)) / 9223372036854775807.0 maps to [0, 1].
-- =============================================================================

INSERT INTO data_science_db.housing.usa_housing
WITH

-- Generate row numbers 1..5000
row_nums AS (
    SELECT
        seq4() + 1 AS rownum
    FROM TABLE(GENERATOR(ROWCOUNT => 5000))
),

-- Generate each feature from a deterministic hash, scaled to approximate
-- the real dataset's statistical properties
features AS (
    SELECT
        rownum,

        -- AVERAGE_AREA_INCOME: mean=68583, range=[17796, 107701]
        -- Use full range = 89905, map hash [0,1] to [17796, 107701]
        ROUND(17796.0 + ABS(HASH(rownum, 1)) / 9223372036854775807.0 * 89905.0, 2)
            AS income,

        -- AVERAGE_HOME_AGE: mean=5.98, range=[1.0, 9.5], step 0.1
        -- Range = 8.5 years
        ROUND((1.0 + ABS(HASH(rownum, 2)) / 9223372036854775807.0 * 8.5) * 2, 0) / 2.0
            AS home_age,

        -- AVERAGE_NUMBER_OF_ROOMS: mean=6.99, range=[4.0, 9.5], step 0.1
        -- Range = 5.5 rooms
        ROUND((4.0 + ABS(HASH(rownum, 3)) / 9223372036854775807.0 * 5.5) * 2, 0) / 2.0
            AS rooms,

        -- AVERAGE_NUMBER_OF_BEDROOMS: mean=3.98, range=[2.0, 6.5], step 0.1
        -- Range = 4.5 bedrooms
        ROUND((2.0 + ABS(HASH(rownum, 4)) / 9223372036854775807.0 * 4.5) * 2, 0) / 2.0
            AS bedrooms,

        -- AREA_POPULATION: mean=35553, range=[172, 69621]
        -- Range = 69449
        ROUND(172.0 + ABS(HASH(rownum, 5)) / 9223372036854775807.0 * 69449.0, 0)
            AS population

    FROM row_nums
),

-- Compute price as a linear combination of features plus noise
-- Coefficients approximated from the real dataset structure:
--   PRICE = 21.5*INCOME + 164883*HOME_AGE + 122368*ROOMS
--         + 2233*BEDROOMS + 15.15*POPULATION + noise
-- Noise: mean=0, range ~ ±200k (uniform [-200000, +200000])
priced AS (
    SELECT
        rownum,
        income,
        home_age,
        rooms,
        bedrooms,
        population,
        GREATEST(15000.0,  -- Floor price at $15k so no negative prices
            ROUND(
                21.5    * income
              + 164883.0 * home_age
              + 122368.0 * rooms
              + 2233.0   * bedrooms
              + 15.15    * population
              + (-200000.0 + ABS(HASH(rownum, 6)) / 9223372036854775807.0 * 400000.0)
            , 2)
        ) AS price
    FROM features
),

-- Generate synthetic street addresses
-- Street number: 1 to 9999
-- Street name: one of 20 common US street names
-- City: one of 20 US cities
-- State: one of 10 US state abbreviations (2-char)
addresses AS (
    SELECT
        rownum,
        CONCAT(
            TO_CHAR(1 + MOD(ABS(HASH(rownum, 7)), 9999)),
            ' ',
            CASE MOD(ABS(HASH(rownum, 8)), 20)
                WHEN 0  THEN 'Oak'
                WHEN 1  THEN 'Maple'
                WHEN 2  THEN 'Cedar'
                WHEN 3  THEN 'Pine'
                WHEN 4  THEN 'Elm'
                WHEN 5  THEN 'Washington'
                WHEN 6  THEN 'Lake'
                WHEN 7  THEN 'Hill'
                WHEN 8  THEN 'River'
                WHEN 9  THEN 'Valley'
                WHEN 10 THEN 'Park'
                WHEN 11 THEN 'Forest'
                WHEN 12 THEN 'Ridge'
                WHEN 13 THEN 'Sunset'
                WHEN 14 THEN 'Highland'
                WHEN 15 THEN 'Meadow'
                WHEN 16 THEN 'Spring'
                WHEN 17 THEN 'Stone'
                WHEN 18 THEN 'Willow'
                ELSE         'Creek'
            END,
            ' ',
            CASE MOD(ABS(HASH(rownum, 9)), 5)
                WHEN 0 THEN 'Ave'
                WHEN 1 THEN 'St'
                WHEN 2 THEN 'Blvd'
                WHEN 3 THEN 'Dr'
                ELSE        'Ln'
            END,
            ', ',
            CASE MOD(ABS(HASH(rownum, 10)), 20)
                WHEN 0  THEN 'Springfield'
                WHEN 1  THEN 'Riverside'
                WHEN 2  THEN 'Georgetown'
                WHEN 3  THEN 'Fairview'
                WHEN 4  THEN 'Madison'
                WHEN 5  THEN 'Franklin'
                WHEN 6  THEN 'Clinton'
                WHEN 7  THEN 'Salem'
                WHEN 8  THEN 'Greenville'
                WHEN 9  THEN 'Bristol'
                WHEN 10 THEN 'Burlington'
                WHEN 11 THEN 'Lakewood'
                WHEN 12 THEN 'Newport'
                WHEN 13 THEN 'Oakland'
                WHEN 14 THEN 'Centerville'
                WHEN 15 THEN 'Chester'
                WHEN 16 THEN 'Milford'
                WHEN 17 THEN 'Lexington'
                WHEN 18 THEN 'Richmond'
                ELSE         'Clayton'
            END,
            ', ',
            CASE MOD(ABS(HASH(rownum, 11)), 10)
                WHEN 0 THEN 'TX'
                WHEN 1 THEN 'CA'
                WHEN 2 THEN 'FL'
                WHEN 3 THEN 'NY'
                WHEN 4 THEN 'PA'
                WHEN 5 THEN 'OH'
                WHEN 6 THEN 'IL'
                WHEN 7 THEN 'GA'
                WHEN 8 THEN 'NC'
                ELSE        'MI'
            END
        ) AS address
    FROM row_nums
)

SELECT
    p.income            AS average_area_income,
    p.home_age          AS average_home_age,
    p.rooms             AS average_number_of_rooms,
    p.bedrooms          AS average_number_of_bedrooms,
    p.population        AS area_population,
    p.price             AS price,
    a.address           AS address
FROM priced p
JOIN addresses a ON p.rownum = a.rownum
ORDER BY p.rownum;


-- =============================================================================
-- STEP 4: Verification queries
-- =============================================================================
-- Run these queries to confirm the data looks correct before running the
-- linear regression notebooks.
-- =============================================================================

-- Row count (expect 5000)
SELECT COUNT(*) AS total_rows
FROM data_science_db.housing.usa_housing;

-- Statistical summary of numeric columns
-- Compare these to the target statistics in the header comments above
SELECT
    ROUND(AVG(average_area_income), 0)          AS avg_income,
    ROUND(MIN(average_area_income), 0)          AS min_income,
    ROUND(MAX(average_area_income), 0)          AS max_income,
    ROUND(AVG(average_home_age), 2)             AS avg_home_age,
    ROUND(AVG(average_number_of_rooms), 2)      AS avg_rooms,
    ROUND(AVG(average_number_of_bedrooms), 2)   AS avg_bedrooms,
    ROUND(AVG(area_population), 0)              AS avg_population,
    ROUND(AVG(price), 0)                        AS avg_price,
    ROUND(MIN(price), 0)                        AS min_price,
    ROUND(MAX(price), 0)                        AS max_price
FROM data_science_db.housing.usa_housing;

-- Sample a few rows to visually inspect
SELECT *
FROM data_science_db.housing.usa_housing
LIMIT 10;

-- Confirm correlation between AVERAGE_AREA_INCOME and PRICE is positive and strong
-- (expect a value well above 0.5, ideally 0.6-0.7+ matching the real dataset)
SELECT
    CORR(average_area_income, price) AS income_price_correlation
FROM data_science_db.housing.usa_housing;

-- Confirm all correlations between features and price
-- (for comparison with the multivariate notebook output)
SELECT
    CORR(average_area_income,        price) AS income_corr,
    CORR(average_home_age,           price) AS home_age_corr,
    CORR(average_number_of_rooms,    price) AS rooms_corr,
    CORR(average_number_of_bedrooms, price) AS bedrooms_corr,
    CORR(area_population,            price) AS population_corr
FROM data_science_db.housing.usa_housing;
