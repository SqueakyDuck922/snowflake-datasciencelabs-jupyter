-- =============================================================================
-- CREATE TEST DATA FOR: data_science_db.movielens.ratings
-- =============================================================================
--
-- PURPOSE:
--   This script creates a synthetic version of the MovieLens ratings table
--   required by the recommender_snowpark notebook. The original table is from
--   the well-known GroupLens MovieLens dataset. This synthetic version mirrors
--   the structure and statistical characteristics of that dataset.
--
-- TABLE: data_science_db.movielens.ratings
--
-- COLUMNS (inferred from notebook code):
--   USERID    INTEGER  - User identifier (notebook maps to contiguous integers)
--   MOVIEID   INTEGER  - Movie identifier, NON-CONTIGUOUS (notebook explicitly
--                        handles this non-contiguity with a mapping step)
--   RATING    FLOAT    - Half-star rating scale: 0.5, 1.0, 1.5, 2.0, 2.5,
--                        3.0, 3.5, 4.0, 4.5, 5.0
--                        (from: Reader(rating_scale=(0.5, 5)) in the notebook)
--   UNIXTIME  INTEGER  - Unix epoch timestamp (dropped before model training
--                        via: movie_ratings.drop('unixtime'))
--
-- ABOUT THE REAL MovieLens DATASET (ml-latest-small):
--   - 610 users, 9,742 movies, 100,836 ratings
--   - Movie IDs are non-contiguous integers (max ID is 193,609)
--   - Ratings use half-star increments from 0.5 to 5.0
--
-- THIS SYNTHETIC DATASET:
--   - 300 users (userid 1 to 300)
--   - 140 movies with non-contiguous IDs (representative sample of real IDs)
--   - ~5,000-7,000 ratings (~14% sampling of all user-movie pairs)
--   - Ratings and timestamps assigned via deterministic hash (reproducible)
--   - Guarantees userid=1 and movieid=110 exist together, as the notebook
--     tests with: session.call("PREDICTION", 1, 110)
--
-- USAGE:
--   Run this entire script once in Snowflake (e.g. via Snowsight worksheets
--   or SnowSQL) before executing the recommender_snowpark notebook.
-- =============================================================================


-- =============================================================================
-- STEP 1: Create database and schema
-- =============================================================================

CREATE DATABASE IF NOT EXISTS data_science_db;
CREATE SCHEMA IF NOT EXISTS data_science_db.movielens;


-- =============================================================================
-- STEP 2: Create the ratings table
-- =============================================================================

CREATE OR REPLACE TABLE data_science_db.movielens.ratings (
    userid    INTEGER  NOT NULL,
    movieid   INTEGER  NOT NULL,
    rating    FLOAT    NOT NULL,
    unixtime  INTEGER  NOT NULL,
    CONSTRAINT pk_ratings PRIMARY KEY (userid, movieid)
);


-- =============================================================================
-- STEP 3: Populate with synthetic ratings data
-- =============================================================================
--
-- Design choices:
--   - 300 users x 140 movies = 42,000 possible (user, movie) pairs
--   - ~14% sampling rate gives ~5,880 ratings (realistic sparse matrix)
--   - Sampling uses a deterministic hash on (userid, movieid) for reproducibility
--   - Rating values use a hash-to-bucket approach ensuring uniform distribution
--     across the 10 possible half-star values (0.5, 1.0, ..., 5.0)
--   - Timestamps are pseudo-random unix times between:
--       946684800  = 2000-01-01 00:00:00 UTC
--       1577836800 = 2020-01-01 00:00:00 UTC
--
-- NOTE: Snowflake does not support VALUES(...) inside a CTE.
--       Movie IDs are provided as a JSON array expanded with FLATTEN(PARSE_JSON(...)),
--       which is the idiomatic Snowflake approach for inlining a list of values.
-- =============================================================================

INSERT INTO data_science_db.movielens.ratings (userid, movieid, rating, unixtime)
WITH

-- ----------------------------------------------------------------------------
-- Non-contiguous movie IDs representative of the real MovieLens dataset.
-- These IDs are a curated sample matching real MovieLens movie IDs.
-- movieid=110 is explicitly included as it is referenced in the notebook's
-- final test call: session.call("PREDICTION", 1, 110)
-- ----------------------------------------------------------------------------
movies AS (
    SELECT f.value::INTEGER AS movieid
    FROM TABLE(FLATTEN(INPUT => PARSE_JSON(
        '[1,2,3,5,6,7,10,11,16,17,25,32,34,36,47,50,52,58,62,70,79,81,95,101,104,108,110,111,117,120,150,153,165,170,173,181,185,195,208,222,235,252,260,266,270,275,280,288,292,296,300,318,329,337,339,344,349,356,358,362,364,367,368,370,378,380,393,401,410,420,431,440,457,480,485,493,500,520,527,529,539,541,543,552,562,564,566,581,586,588,589,590,592,593,597,608,616,631,648,650,661,673,733,736,741,745,750,780,786,802,811,812,858,880,898,900,910,912,919,923,924,930,938,945,953,954,956,959,1029,1032,1036,1047,1060,1073,1089,1097,1122,1136,1193,1196]'
    ))) f
),

-- ----------------------------------------------------------------------------
-- Generate users 1 to 300 using Snowflake's sequence generator
-- ----------------------------------------------------------------------------
users AS (
    SELECT seq4() + 1 AS userid
    FROM TABLE(GENERATOR(ROWCOUNT => 300))
),

-- ----------------------------------------------------------------------------
-- Cross join all users x movies, then:
--   1. Sample ~1 in 7 pairs using a deterministic hash (= ~14% of all pairs)
--   2. Assign a rating from {0.5, 1.0, ..., 5.0} using a hash-based bucket
--   3. Assign a unix timestamp in range [2000-01-01, 2020-01-01]
-- Using HASH() instead of RANDOM() makes results reproducible.
-- ----------------------------------------------------------------------------
cross_product AS (
    SELECT
        u.userid,
        m.movieid,

        -- Sampling decision: keep this (user, movie) pair?
        -- MOD(..., 7) gives values 0-6; keeping only 0 retains ~1/7 = 14%
        MOD(ABS(HASH(u.userid, m.movieid)), 7)              AS keep_flag,

        -- Rating: map hash bucket to one of 10 values: 0.5, 1.0, ..., 5.0
        -- MOD(..., 10) gives 0-9; +1 gives 1-10; * 0.5 gives 0.5-5.0
        ((MOD(ABS(HASH(u.userid, m.movieid, 42)), 10) + 1) * 0.5)::FLOAT
                                                            AS rating,

        -- Unix timestamp between 946684800 (2000-01-01) and 1577836800 (2020-01-01)
        -- Range = 631,152,000 seconds
        (946684800 + MOD(ABS(HASH(u.userid, m.movieid, 99)), 631152000))::INTEGER
                                                            AS unixtime
    FROM users u
    CROSS JOIN movies m
),

-- Apply the sampling filter (keep only rows where keep_flag = 0)
sampled AS (
    SELECT userid, movieid, rating, unixtime
    FROM cross_product
    WHERE keep_flag = 0
)

-- Final output: sampled ratings UNION with guaranteed seed rows
SELECT userid, movieid, rating, unixtime
FROM sampled

UNION ALL

-- Guarantee that the specific (userid=1, movieid=110) pair exists.
-- This pair is used in the notebook's final test: session.call("PREDICTION", 1, 110)
-- The WHERE NOT EXISTS guard prevents a duplicate if the sampling already included it.
SELECT 1, 110, 4.0, 1000000000
WHERE NOT EXISTS (
    SELECT 1 FROM sampled WHERE userid = 1 AND movieid = 110
);


-- =============================================================================
-- STEP 4: Verification queries
-- =============================================================================
-- Run these queries to confirm the data looks correct before running the notebook.
-- =============================================================================

-- Total number of ratings (expect approx 5,500 - 6,500)
SELECT COUNT(*) AS total_ratings
FROM data_science_db.movielens.ratings;

-- Count of distinct users and movies in the data
SELECT
    COUNT(DISTINCT userid)  AS distinct_users,
    COUNT(DISTINCT movieid) AS distinct_movies
FROM data_science_db.movielens.ratings;

-- Sample a few rows to visually inspect
SELECT *
FROM data_science_db.movielens.ratings
ORDER BY userid, movieid
LIMIT 10;

-- Rating distribution: verify half-star values 0.5 to 5.0 are evenly spread
SELECT
    rating,
    COUNT(*) AS count
FROM data_science_db.movielens.ratings
GROUP BY rating
ORDER BY rating;

-- Confirm movieid values are non-contiguous (show the 5 highest movieids)
SELECT DISTINCT movieid
FROM data_science_db.movielens.ratings
ORDER BY movieid DESC
LIMIT 5;

-- Confirm the critical test row exists: userid=1, movieid=110
-- (required for: session.call("PREDICTION", 1, 110) in the notebook)
SELECT *
FROM data_science_db.movielens.ratings
WHERE userid = 1
  AND movieid = 110;
