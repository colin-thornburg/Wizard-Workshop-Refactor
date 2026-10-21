/*******************************************************************************
  Procedure : ANALYTICS.LEGACY_ETL.SP_LOAD_CUSTOMER_LTV
  Target    : ANALYTICS.LEGACY.CUSTOMER_LTV  (truncate + reload)
  Schedule  : Daily 02:00 via Task ANALYTICS.LEGACY_ETL.TSK_NIGHTLY_LTV
  Owner     : Customer Analytics (DL-cust-analytics)

  Purpose   : One row per (non-test) customer with lifetime revenue, refunds,
              recency and a marketing segment used by CRM audiences.

  Change log
  ----------
  2021-03-02  JKR   Initial version (ported from SQL Server dbo.usp_CustLTV)
  2021-11-18  JKR   Multi-currency: convert to USD with monthly FX rates
  2022-06-09  APS   CR-1188 refunds converted at ORDER month rate, not return month
  2023-01-23  APS   CR-1402 add AT_RISK segment (no order in 180 days)
  2023-08-14  MDV   CR-1655 Platinum loyalty members are always VIP (overrides AT_RISK)
  2024-04-30  MDV   INC-3307 trim/upper dirty status + loyalty values from source
*******************************************************************************/
CREATE OR REPLACE PROCEDURE ANALYTICS.LEGACY_ETL.SP_LOAD_CUSTOMER_LTV(P_AS_OF_DATE DATE)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_batch_id      NUMBER;
    v_rows_loaded   NUMBER DEFAULT 0;
    v_step          VARCHAR DEFAULT 'INIT';
    v_high_value    NUMBER(18,2) DEFAULT 2000.00;   -- per Marketing (2023 segmentation memo)
    v_mid_value     NUMBER(18,2) DEFAULT 500.00;
    v_at_risk_days  NUMBER DEFAULT 180;
BEGIN
    v_batch_id := (SELECT COALESCE(MAX(BATCH_ID), 0) + 1 FROM ANALYTICS.LEGACY_ETL.ETL_AUDIT_LOG);

    INSERT INTO ANALYTICS.LEGACY_ETL.ETL_AUDIT_LOG (BATCH_ID, PROC_NAME, STEP, STATUS, LOGGED_AT)
    VALUES (:v_batch_id, 'SP_LOAD_CUSTOMER_LTV', 'START', 'RUNNING', CURRENT_TIMESTAMP());

    ---------------------------------------------------------------------------
    -- STEP 1: eligible customers (exclude QA / test accounts)
    ---------------------------------------------------------------------------
    v_step := 'TMP_CUSTOMERS';
    CREATE OR REPLACE TEMPORARY TABLE TMP_CUSTOMERS AS
    SELECT
        C.CUSTOMER_ID,
        TRIM(C.FIRST_NAME) || ' ' || TRIM(C.LAST_NAME)       AS CUSTOMER_NAME,
        LOWER(TRIM(C.EMAIL))                                 AS EMAIL,
        UPPER(TRIM(C.STATE))                                 AS STATE,
        COALESCE(NULLIF(UPPER(TRIM(C.LOYALTY_TIER)), ''), 'NONE') AS LOYALTY_TIER
    FROM RAW.SHOP.CUSTOMERS C
    WHERE COALESCE(UPPER(TRIM(C.IS_TEST_ACCOUNT)), 'N') <> 'Y';

    ---------------------------------------------------------------------------
    -- STEP 2: valid orders (completed / shipped / returned) up to as-of date
    ---------------------------------------------------------------------------
    v_step := 'TMP_VALID_ORDERS';
    CREATE OR REPLACE TEMPORARY TABLE TMP_VALID_ORDERS AS
    SELECT
        O.ORDER_ID,
        O.CUSTOMER_ID,
        O.ORDER_DATE,
        UPPER(TRIM(O.CURRENCY_CODE))                         AS CURRENCY_CODE,
        DATE_TRUNC('MONTH', O.ORDER_DATE)                    AS RATE_MONTH
    FROM RAW.SHOP.ORDERS O
    INNER JOIN TMP_CUSTOMERS C
        ON C.CUSTOMER_ID = O.CUSTOMER_ID
    WHERE UPPER(TRIM(O.STATUS)) IN ('COMPLETED', 'SHIPPED', 'RETURNED')
      AND O.ORDER_DATE <= :P_AS_OF_DATE;

    ---------------------------------------------------------------------------
    -- STEP 3: line revenue in USD (net of discount, excl. shipping)
    --   discount is rounded per line BEFORE conversion; USD rounded per line.
    --   USD orders have no FX row -> rate 1.
    ---------------------------------------------------------------------------
    v_step := 'TMP_LINE_REVENUE';
    CREATE OR REPLACE TEMPORARY TABLE TMP_LINE_REVENUE AS
    SELECT
        L.ORDER_LINE_ID,
        VO.ORDER_ID,
        VO.CUSTOMER_ID,
        COALESCE(FX.USD_PER_UNIT, 1)                                        AS USD_RATE,
        (L.QUANTITY * L.UNIT_PRICE)
            - ROUND(L.QUANTITY * L.UNIT_PRICE * L.DISCOUNT_PCT, 2)          AS LINE_NET_LOCAL,
        ROUND(((L.QUANTITY * L.UNIT_PRICE)
            - ROUND(L.QUANTITY * L.UNIT_PRICE * L.DISCOUNT_PCT, 2))
            * COALESCE(FX.USD_PER_UNIT, 1), 2)                              AS LINE_NET_USD
    FROM RAW.SHOP.ORDER_LINES L
    INNER JOIN TMP_VALID_ORDERS VO
        ON VO.ORDER_ID = L.ORDER_ID
    LEFT JOIN RAW.SHOP.FX_RATES FX
        ON  FX.CURRENCY_CODE = VO.CURRENCY_CODE
        AND FX.RATE_MONTH    = VO.RATE_MONTH;

    ---------------------------------------------------------------------------
    -- STEP 4: refunds in USD at the ORDER month rate (CR-1188), per return row
    ---------------------------------------------------------------------------
    v_step := 'TMP_REFUNDS';
    CREATE OR REPLACE TEMPORARY TABLE TMP_REFUNDS AS
    SELECT
        LR.CUSTOMER_ID,
        SUM(ROUND(R.REFUND_AMOUNT * LR.USD_RATE, 2))         AS REFUNDS_USD
    FROM RAW.SHOP.RETURNS R
    INNER JOIN TMP_LINE_REVENUE LR
        ON LR.ORDER_LINE_ID = R.ORDER_LINE_ID
    GROUP BY LR.CUSTOMER_ID;

    ---------------------------------------------------------------------------
    -- STEP 5: customer rollup (all eligible customers, incl. no orders)
    ---------------------------------------------------------------------------
    v_step := 'TMP_CUSTOMER_ROLLUP';
    CREATE OR REPLACE TEMPORARY TABLE TMP_CUSTOMER_ROLLUP AS
    WITH ORDER_STATS AS (
        SELECT
            CUSTOMER_ID,
            COUNT(DISTINCT ORDER_ID)  AS TOTAL_ORDERS,
            MIN(ORDER_DATE)           AS FIRST_ORDER_DATE,
            MAX(ORDER_DATE)           AS LAST_ORDER_DATE
        FROM TMP_VALID_ORDERS
        GROUP BY CUSTOMER_ID
    ),
    REVENUE AS (
        SELECT CUSTOMER_ID, SUM(LINE_NET_USD) AS PRODUCT_REVENUE_USD
        FROM TMP_LINE_REVENUE
        GROUP BY CUSTOMER_ID
    )
    SELECT
        C.CUSTOMER_ID,
        C.CUSTOMER_NAME,
        C.EMAIL,
        C.STATE,
        C.LOYALTY_TIER,
        OS.FIRST_ORDER_DATE,
        OS.LAST_ORDER_DATE,
        COALESCE(OS.TOTAL_ORDERS, 0)                          AS TOTAL_ORDERS,
        COALESCE(RV.PRODUCT_REVENUE_USD, 0)                   AS PRODUCT_REVENUE_USD,
        COALESCE(RF.REFUNDS_USD, 0)                           AS REFUNDS_USD
    FROM TMP_CUSTOMERS C
    LEFT JOIN ORDER_STATS OS ON OS.CUSTOMER_ID = C.CUSTOMER_ID
    LEFT JOIN REVENUE     RV ON RV.CUSTOMER_ID = C.CUSTOMER_ID
    LEFT JOIN TMP_REFUNDS RF ON RF.CUSTOMER_ID = C.CUSTOMER_ID;

    ---------------------------------------------------------------------------
    -- STEP 6: reload target with base segment
    ---------------------------------------------------------------------------
    v_step := 'LOAD_TARGET';
    TRUNCATE TABLE ANALYTICS.LEGACY.CUSTOMER_LTV;

    INSERT INTO ANALYTICS.LEGACY.CUSTOMER_LTV (
        CUSTOMER_ID, CUSTOMER_NAME, EMAIL, STATE, LOYALTY_TIER,
        FIRST_ORDER_DATE, LAST_ORDER_DATE, TOTAL_ORDERS,
        PRODUCT_REVENUE_USD, REFUNDS_USD, NET_REVENUE_USD, AVG_ORDER_VALUE_USD,
        DAYS_SINCE_LAST_ORDER, CUSTOMER_SEGMENT, ETL_LOAD_TS
    )
    SELECT
        CUSTOMER_ID,
        CUSTOMER_NAME,
        EMAIL,
        STATE,
        LOYALTY_TIER,
        FIRST_ORDER_DATE,
        LAST_ORDER_DATE,
        TOTAL_ORDERS,
        PRODUCT_REVENUE_USD,
        REFUNDS_USD,
        PRODUCT_REVENUE_USD - REFUNDS_USD                                   AS NET_REVENUE_USD,
        CASE WHEN TOTAL_ORDERS = 0 THEN 0
             ELSE ROUND(PRODUCT_REVENUE_USD / TOTAL_ORDERS, 2) END          AS AVG_ORDER_VALUE_USD,
        DATEDIFF('DAY', LAST_ORDER_DATE, :P_AS_OF_DATE)                     AS DAYS_SINCE_LAST_ORDER,
        CASE
            WHEN TOTAL_ORDERS = 0                                   THEN 'PROSPECT'
            WHEN PRODUCT_REVENUE_USD - REFUNDS_USD >= :v_high_value THEN 'HIGH_VALUE'
            WHEN PRODUCT_REVENUE_USD - REFUNDS_USD >= :v_mid_value  THEN 'MID_VALUE'
            ELSE 'LOW_VALUE'
        END                                                                 AS CUSTOMER_SEGMENT,
        CURRENT_TIMESTAMP()
    FROM TMP_CUSTOMER_ROLLUP;

    v_rows_loaded := SQLROWCOUNT;

    ---------------------------------------------------------------------------
    -- STEP 7: CR-1402 lapsed valuable customers -> AT_RISK
    ---------------------------------------------------------------------------
    v_step := 'UPD_AT_RISK';
    UPDATE ANALYTICS.LEGACY.CUSTOMER_LTV
       SET CUSTOMER_SEGMENT = 'AT_RISK'
     WHERE DAYS_SINCE_LAST_ORDER > :v_at_risk_days
       AND CUSTOMER_SEGMENT IN ('HIGH_VALUE', 'MID_VALUE');

    ---------------------------------------------------------------------------
    -- STEP 8: CR-1655 Platinum members with at least one order are VIP.
    --   MUST run after STEP 7 (VIP wins over AT_RISK).
    ---------------------------------------------------------------------------
    v_step := 'UPD_VIP';
    UPDATE ANALYTICS.LEGACY.CUSTOMER_LTV
       SET CUSTOMER_SEGMENT = 'VIP'
     WHERE LOYALTY_TIER = 'PLATINUM'
       AND TOTAL_ORDERS > 0;

    INSERT INTO ANALYTICS.LEGACY_ETL.ETL_AUDIT_LOG (BATCH_ID, PROC_NAME, STEP, STATUS, ROW_COUNT, LOGGED_AT)
    VALUES (:v_batch_id, 'SP_LOAD_CUSTOMER_LTV', 'END', 'SUCCESS', :v_rows_loaded, CURRENT_TIMESTAMP());

    RETURN 'SP_LOAD_CUSTOMER_LTV batch ' || v_batch_id || ' loaded ' || v_rows_loaded || ' rows';

EXCEPTION
    WHEN OTHER THEN
        INSERT INTO ANALYTICS.LEGACY_ETL.ETL_AUDIT_LOG (BATCH_ID, PROC_NAME, STEP, STATUS, ERROR_MESSAGE, LOGGED_AT)
        VALUES (:v_batch_id, 'SP_LOAD_CUSTOMER_LTV', :v_step, 'FAILED', :SQLERRM, CURRENT_TIMESTAMP());
        RAISE;
END;
$$;

-- Nightly call (as-of = yesterday). Current LEGACY.CUSTOMER_LTV snapshot: as-of '2026-09-30'.
-- CALL ANALYTICS.LEGACY_ETL.SP_LOAD_CUSTOMER_LTV(DATEADD('DAY', -1, CURRENT_DATE()));
