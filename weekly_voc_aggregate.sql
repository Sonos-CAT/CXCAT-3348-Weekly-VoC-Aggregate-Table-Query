-- INSTRUCTIONS FOR ADAM:
-- 1. Run this query as soon as you come in on Monday morning to update the DEV table.
-- 2. Refresh the Tableau datasource via the Tableau application. 
-- 3. COORDINATION: Work with Data Engineering to move this from JEREMIAH_DEV_EXPLORATORY 
--    to the production CX_MODELS folder and automate the load.
-- 4. ALIGNMENT: Ensure Josh and Sascha are aligned on the outputs from VIZ_OWNERS_SURVEY_CORP.
-- 5. REQS: If you need more dimensions, contact Jeremiah.

CREATE OR REPLACE TABLE "CX_ANALYTICS_DEV"."JEREMIAH_DEV_EXPLORATORY"."CX_VOC_WEEKLY_REPORT_OWNERS_SURVEY_SCORES" AS
WITH SurveyData AS (
    SELECT
        owner.FISCAL_MONTH_DESC,
        owner.FISCAL_MONTH_ID,
        owner.FISCAL_QUARTER_DESC,
        owner.FISCAL_QUARTER_ID,
        owner.FISCAL_WEEK_DESC,
        owner.FISCAL_WEEK_ID,
        owner.FISCAL_YEAR_ID,
        owner.SONOS_ID,
        owner.NPS_SCORE,
        owner.purchase_additional_likelihood AS REPURCHASE_SCORE
    FROM
        DATA_WAREHOUSE.WAREHOUSE_SURVEY.VIZ_OWNERS_SURVEY_CORP AS owner
    QUALIFY DENSE_RANK() OVER (ORDER BY owner.FISCAL_WEEK_ID DESC) BETWEEN 2 AND 13
),

WeeklyMetrics AS (
    SELECT
        FISCAL_MONTH_DESC, FISCAL_MONTH_ID, FISCAL_QUARTER_DESC,
        FISCAL_QUARTER_ID, FISCAL_WEEK_DESC, FISCAL_WEEK_ID, FISCAL_YEAR_ID,
        COUNT(DISTINCT CASE WHEN NPS_SCORE >= 9 THEN SONOS_ID END) AS promoter_count,
        COUNT(DISTINCT CASE WHEN NPS_SCORE BETWEEN 7 AND 8 THEN SONOS_ID END) AS passive_count,
        COUNT(DISTINCT CASE WHEN NPS_SCORE <= 6 THEN SONOS_ID END) AS detractor_count,
        COUNT(DISTINCT SONOS_ID) AS nps_response_volume,
        SUM(REPURCHASE_SCORE) AS repurchase_sum,
        COUNT(DISTINCT CASE WHEN REPURCHASE_SCORE IS NOT NULL THEN SONOS_ID END) AS ltr_volume
    FROM SurveyData
    GROUP BY 1,2,3,4,5,6,7
)

SELECT
    FISCAL_MONTH_DESC,
    FISCAL_MONTH_ID,
    FISCAL_QUARTER_DESC,
    FISCAL_QUARTER_ID,
    FISCAL_WEEK_DESC,
    FISCAL_WEEK_ID,
    FISCAL_YEAR_ID,
    ROUND(((promoter_count - detractor_count)::FLOAT / NULLIF(nps_response_volume, 0)) * 100, 2) AS FISCAL_WEEK_NPS_SCORE,
    ROUND((repurchase_sum / NULLIF(ltr_volume, 0)), 2) AS REPURCHASE_SCORE,
    ROUND(((
        SUM(promoter_count) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) -
        SUM(detractor_count) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)
    )::FLOAT /
        NULLIF(SUM(nps_response_volume) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 0)
    ) * 100, 2) AS NPS_4_WEEK_ROLLING,
    ROUND((
        SUM(repurchase_sum) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) /
        NULLIF(SUM(ltr_volume) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 0)
    ), 2) AS LTR_4_WEEK_ROLLING,
    nps_response_volume AS NPS_RESPONSE_VOLUME,
    ltr_volume AS LTR_VOLUME,
    ROUND((promoter_count::FLOAT / NULLIF(nps_response_volume, 0)) * 100, 2) AS "NPS Promoters %",
    ROUND((passive_count::FLOAT / NULLIF(nps_response_volume, 0)) * 100, 2) AS "NPS Passive %",
    ROUND((detractor_count::FLOAT / NULLIF(nps_response_volume, 0)) * 100, 2) AS "NPS Detractor %"
FROM
    WeeklyMetrics
ORDER BY
    FISCAL_WEEK_ID DESC;
