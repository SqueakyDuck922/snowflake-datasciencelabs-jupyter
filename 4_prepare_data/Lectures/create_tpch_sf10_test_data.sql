USE role accountadmin;

-- =============================================================================
-- TPC-H SF10 Test Data Generator
-- Creates TRAINING_DB.TPCH_SF10 schema with CUSTOMER, ORDERS, and LINEITEM
-- tables populated with realistic test data.
--
-- Scale: ~500 customers, ~2,000 orders, ~8,000 line items
-- Compatible with: 4_prepare_data/Lectures/2_Using_Snowpark_DataFrames_MINE.ipynb
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Database and Schema Setup
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS TRAINING_DB;

CREATE SCHEMA IF NOT EXISTS TRAINING_DB.TPCH_SF10;

USE DATABASE TRAINING_DB;
USE SCHEMA TPCH_SF10;


-- -----------------------------------------------------------------------------
-- 2. CUSTOMER Table
--    TPC-H columns used in notebook: C_CUSTKEY, C_NAME, C_PHONE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE TRAINING_DB.TPCH_SF10.CUSTOMER (
    C_CUSTKEY     INTEGER       NOT NULL,
    C_NAME        VARCHAR(25)   NOT NULL,
    C_ADDRESS     VARCHAR(40)   NOT NULL,
    C_NATIONKEY   INTEGER       NOT NULL,
    C_PHONE       CHAR(15)      NOT NULL,
    C_ACCTBAL     DECIMAL(15,2) NOT NULL,
    C_MKTSEGMENT  CHAR(10)      NOT NULL,
    C_COMMENT     VARCHAR(117)  NOT NULL,
    PRIMARY KEY (C_CUSTKEY)
);

INSERT INTO TRAINING_DB.TPCH_SF10.CUSTOMER
WITH nation_keys AS (
    SELECT column1 AS nk FROM VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                     (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                     (20),(21),(22),(23),(24)
),
segments AS (
    SELECT column1 AS seg FROM VALUES
        ('AUTOMOBILE'),('BUILDING'),('FURNITURE'),('HOUSEHOLD'),('MACHINERY')
),
seq AS (
    SELECT SEQ4() + 1 AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
)
SELECT
    seq.rn                                                                          AS C_CUSTKEY,
    'Customer#' || LPAD(seq.rn::VARCHAR, 9, '0')                                   AS C_NAME,
    RANDSTR(UNIFORM(10, 40, RANDOM()), RANDOM())                                    AS C_ADDRESS,
    ABS(MOD(UNIFORM(0, 24, RANDOM()), 25))                                          AS C_NATIONKEY,
    -- Phone format: nn-nnn-nnn-nnnn
    LPAD(UNIFORM(10, 34, RANDOM())::VARCHAR, 2, '0') || '-'
        || LPAD(UNIFORM(100, 999, RANDOM())::VARCHAR, 3, '0') || '-'
        || LPAD(UNIFORM(100, 999, RANDOM())::VARCHAR, 3, '0') || '-'
        || LPAD(UNIFORM(1000, 9999, RANDOM())::VARCHAR, 4, '0')                     AS C_PHONE,
    ROUND(UNIFORM(-999.99, 9999.99, RANDOM())::DECIMAL(15,2), 2)                    AS C_ACCTBAL,
    (SELECT seg FROM segments ORDER BY RANDOM() LIMIT 1)                            AS C_MKTSEGMENT,
    'Customer comment ' || seq.rn::VARCHAR                                          AS C_COMMENT
FROM seq;


-- -----------------------------------------------------------------------------
-- 3. ORDERS Table
--    TPC-H columns used in notebook: O_ORDERKEY, O_CUSTKEY
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE TRAINING_DB.TPCH_SF10.ORDERS (
    O_ORDERKEY      INTEGER       NOT NULL,
    O_CUSTKEY       INTEGER       NOT NULL,
    O_ORDERSTATUS   CHAR(1)       NOT NULL,
    O_TOTALPRICE    DECIMAL(15,2) NOT NULL,
    O_ORDERDATE     DATE          NOT NULL,
    O_ORDERPRIORITY CHAR(15)      NOT NULL,
    O_CLERK         CHAR(15)      NOT NULL,
    O_SHIPPRIORITY  INTEGER       NOT NULL,
    O_COMMENT       VARCHAR(79)   NOT NULL,
    PRIMARY KEY (O_ORDERKEY)
);

INSERT INTO TRAINING_DB.TPCH_SF10.ORDERS
WITH priorities AS (
    SELECT column1 AS pri FROM VALUES
        ('1-URGENT'),('2-HIGH'),('3-MEDIUM'),('4-NOT SPECIFIED'),('5-LOW')
),
statuses AS (
    SELECT column1 AS st FROM VALUES ('O'),('F'),('P')
),
seq AS (
    SELECT SEQ4() + 1 AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))
)
SELECT
    seq.rn                                                                          AS O_ORDERKEY,
    -- Assign customers 1-500 randomly, ensuring every customer gets at least some orders
    UNIFORM(1, 500, RANDOM())                                                       AS O_CUSTKEY,
    (SELECT st FROM statuses ORDER BY RANDOM() LIMIT 1)                             AS O_ORDERSTATUS,
    ROUND(UNIFORM(1000.00, 500000.00, RANDOM())::DECIMAL(15,2), 2)                  AS O_TOTALPRICE,
    DATEADD('day', -UNIFORM(0, 2557, RANDOM()), '1998-12-01'::DATE)                 AS O_ORDERDATE,
    (SELECT pri FROM priorities ORDER BY RANDOM() LIMIT 1)                          AS O_ORDERPRIORITY,
    'Clerk#' || LPAD(UNIFORM(1, 1000, RANDOM())::VARCHAR, 9, '0')                   AS O_CLERK,
    0                                                                               AS O_SHIPPRIORITY,
    'Order comment ' || seq.rn::VARCHAR                                             AS O_COMMENT
FROM seq;


-- -----------------------------------------------------------------------------
-- 4. LINEITEM Table
--    TPC-H columns used in notebook:
--      L_ORDERKEY, L_QUANTITY (DECIMAL 12,2), L_EXTENDEDPRICE,
--      L_DISCOUNT, L_TAX, L_SHIPINSTRUCT
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE TRAINING_DB.TPCH_SF10.LINEITEM (
    L_ORDERKEY      INTEGER       NOT NULL,
    L_PARTKEY       INTEGER       NOT NULL,
    L_SUPPKEY       INTEGER       NOT NULL,
    L_LINENUMBER    INTEGER       NOT NULL,
    L_QUANTITY      DECIMAL(12,2) NOT NULL,
    L_EXTENDEDPRICE DECIMAL(15,2) NOT NULL,
    L_DISCOUNT      DECIMAL(15,2) NOT NULL,   -- range 0.00 – 0.10
    L_TAX           DECIMAL(15,2) NOT NULL,   -- range 0.00 – 0.08
    L_RETURNFLAG    CHAR(1)       NOT NULL,   -- 'A', 'N', 'R'
    L_LINESTATUS    CHAR(1)       NOT NULL,   -- 'O', 'F'
    L_SHIPDATE      DATE          NOT NULL,
    L_COMMITDATE    DATE          NOT NULL,
    L_RECEIPTDATE   DATE          NOT NULL,
    L_SHIPINSTRUCT  CHAR(25)      NOT NULL,   -- 4 possible values
    L_SHIPMODE      CHAR(10)      NOT NULL,   -- 7 possible values
    L_COMMENT       VARCHAR(44)   NOT NULL,
    PRIMARY KEY (L_ORDERKEY, L_LINENUMBER)
);

INSERT INTO TRAINING_DB.TPCH_SF10.LINEITEM
WITH ship_instructions AS (
    SELECT column1 AS si FROM VALUES
        ('DELIVER IN PERSON     '),
        ('COLLECT COD           '),
        ('NONE                  '),
        ('TAKE BACK RETURN      ')
),
ship_modes AS (
    SELECT column1 AS sm FROM VALUES
        ('REG AIR  '),('AIR      '),('RAIL     '),
        ('SHIP     '),('TRUCK    '),('MAIL     '),('FOB      ')
),
return_flags AS (
    SELECT column1 AS rf FROM VALUES ('A'),('N'),('R')
),
line_statuses AS (
    SELECT column1 AS ls FROM VALUES ('O'),('F')
),
-- Generate ~4 line items per order (8000 rows across 2000 orders)
seq AS (
    SELECT
        SEQ4() + 1                          AS rn,
        -- Spread rows across orders 1-2000, 4 line items each
        CEIL((SEQ4() + 1) / 4.0)::INTEGER   AS derived_orderkey,
        MOD(SEQ4(), 4) + 1                  AS linenumber
    FROM TABLE(GENERATOR(ROWCOUNT => 8000))
),
base AS (
    SELECT
        seq.derived_orderkey                                                        AS L_ORDERKEY,
        UNIFORM(1, 20000, RANDOM())                                                 AS L_PARTKEY,
        UNIFORM(1, 10000, RANDOM())                                                 AS L_SUPPKEY,
        seq.linenumber                                                              AS L_LINENUMBER,
        -- Quantity: 1.00 – 50.00 (integer quantities stored as DECIMAL)
        ROUND(UNIFORM(1, 50, RANDOM())::DECIMAL(12,2), 2)                           AS L_QUANTITY,
        -- Extended price = quantity * unit price (unit price 900 – 104950)
        ROUND(
            UNIFORM(1, 50, RANDOM()) * UNIFORM(900, 104950, RANDOM()) / 100.0,
            2
        )::DECIMAL(15,2)                                                            AS L_EXTENDEDPRICE,
        -- Discount: 0.00 – 0.10 in steps of 0.01
        (UNIFORM(0, 10, RANDOM()) / 100.0)::DECIMAL(15,2)                          AS L_DISCOUNT,
        -- Tax: 0.00 – 0.08 in steps of 0.01
        (UNIFORM(0, 8, RANDOM()) / 100.0)::DECIMAL(15,2)                           AS L_TAX,
        (SELECT rf FROM return_flags ORDER BY RANDOM() LIMIT 1)                     AS L_RETURNFLAG,
        (SELECT ls FROM line_statuses ORDER BY RANDOM() LIMIT 1)                    AS L_LINESTATUS,
        -- Ship date: between 1992-01-02 and 1998-12-01
        DATEADD('day', UNIFORM(0, 2557, RANDOM()), '1992-01-02'::DATE)              AS L_SHIPDATE,
        DATEADD('day', UNIFORM(0, 2557, RANDOM()), '1992-01-02'::DATE)              AS L_COMMITDATE,
        DATEADD('day', UNIFORM(0, 2557, RANDOM()), '1992-01-02'::DATE)              AS L_RECEIPTDATE,
        TRIM((SELECT si FROM ship_instructions ORDER BY RANDOM() LIMIT 1))          AS L_SHIPINSTRUCT,
        TRIM((SELECT sm FROM ship_modes ORDER BY RANDOM() LIMIT 1))                 AS L_SHIPMODE,
        'Lineitem comment ' || seq.rn::VARCHAR                                      AS L_COMMENT
    FROM seq
)
SELECT * FROM base;


-- -----------------------------------------------------------------------------
-- 5. Verification Queries
-- -----------------------------------------------------------------------------

-- Row counts
SELECT 'CUSTOMER'  AS tbl, COUNT(*) AS row_count FROM TRAINING_DB.TPCH_SF10.CUSTOMER
UNION ALL
SELECT 'ORDERS'    AS tbl, COUNT(*) AS row_count FROM TRAINING_DB.TPCH_SF10.ORDERS
UNION ALL
SELECT 'LINEITEM'  AS tbl, COUNT(*) AS row_count FROM TRAINING_DB.TPCH_SF10.LINEITEM
ORDER BY tbl;

-- Sample LINEITEM rows showing columns used in the notebook
SELECT
    L_ORDERKEY,
    L_QUANTITY,
    L_EXTENDEDPRICE,
    L_DISCOUNT,
    L_TAX,
    L_SHIPINSTRUCT
FROM TRAINING_DB.TPCH_SF10.LINEITEM
LIMIT 10;

-- Verify the 4 SHIPINSTRUCT values are present (used in group_by in notebook)
SELECT L_SHIPINSTRUCT, COUNT(*) AS cnt
FROM TRAINING_DB.TPCH_SF10.LINEITEM
GROUP BY L_SHIPINSTRUCT
ORDER BY L_SHIPINSTRUCT;

-- Verify the notebook's multi-table join query works
-- (mirrors the Session.sql query in the notebook)
SELECT
    CUS.C_NAME                  AS CUSTOMER_NAME,
    SUB.OC                      AS ORDER_COUNT,
    SUB.CK                      AS CUSTOMER_ID,
    SUB.OK                      AS ORDER_ID,
    SUB.TQ::INT                 AS LINEITEM_QUANTITY_SUM
FROM TRAINING_DB.TPCH_SF10.CUSTOMER CUS
    JOIN (
        SELECT
            CU.C_CUSTKEY        AS CK,
            ORD.O_ORDERKEY      AS OK,
            SUM(LI.L_QUANTITY)  AS TQ,
            COUNT(ORD.O_ORDERKEY) AS OC
        FROM TRAINING_DB.TPCH_SF10.LINEITEM LI
            JOIN TRAINING_DB.TPCH_SF10.ORDERS ORD
                ON LI.L_ORDERKEY = ORD.O_ORDERKEY
            JOIN TRAINING_DB.TPCH_SF10.CUSTOMER CU
                ON CU.C_CUSTKEY = ORD.O_CUSTKEY
        GROUP BY CU.C_CUSTKEY, ORD.O_ORDERKEY
        HAVING SUM(LI.L_QUANTITY) > 100
    ) SUB
        ON CUS.C_CUSTKEY = SUB.CK
ORDER BY
    LINEITEM_QUANTITY_SUM DESC,
    ORDER_COUNT DESC,
    CUSTOMER_ID ASC,
    ORDER_ID ASC
LIMIT 12;