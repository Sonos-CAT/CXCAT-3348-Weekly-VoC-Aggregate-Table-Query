-- run this query as soon as you come in on Monday morning. then refresh the tableau datasource by going into the Tableau application and refresh datasource. 
-- work with Data Engineering to productionalize this table loading once a week on Monday (or Sunday) so you no longer need to manually refresh the data. 
-- work with Josh and Sascha to make sure they are aligned on the outputs and use case for WBR but based on their Owners_Survey_Corp view
-- If you need additional requirements, chat with Jeremiah so he can help you source additional dimensions as needed

CREATE OR REPLACE TABLE "CX_ANALYTICS"."CX_MODELS"."CX_VOC_WEEKLY_REPORT_OWNERS_SURVEY_SCORES" AS
WITH SurveyData AS (
    -- CTE 1: Grab raw data and filter for the last 12 completed weeks
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
    -- CTE 2: Aggregations
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

-- Final SELECT: Calculate metrics and enforce 2-decimal rounding globally
SELECT
    FISCAL_MONTH_DESC,
    FISCAL_MONTH_ID,
    FISCAL_QUARTER_DESC,
    FISCAL_QUARTER_ID,
    FISCAL_WEEK_DESC,
    FISCAL_WEEK_ID,
    FISCAL_YEAR_ID,

    -- Weekly Metrics (Rounded to 2)
    ROUND(((promoter_count - detractor_count)::FLOAT / NULLIF(nps_response_volume, 0)) * 100, 2) AS FISCAL_WEEK_NPS_SCORE,
    ROUND((repurchase_sum / NULLIF(ltr_volume, 0)), 2) AS REPURCHASE_SCORE,
    
    -- Rolling 4-Week NPS (Rounded to 2)
    ROUND(((
        SUM(promoter_count) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) -
        SUM(detractor_count) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)
    )::FLOAT /
        NULLIF(SUM(nps_response_volume) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 0)
    ) * 100, 2) AS NPS_4_WEEK_ROLLING,
    
    -- Rolling 4-Week LTR (Rounded to 2)
    ROUND((
        SUM(repurchase_sum) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) /
        NULLIF(SUM(ltr_volume) OVER (ORDER BY FISCAL_WEEK_ID ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 0)
    ), 2) AS LTR_4_WEEK_ROLLING,
    
    -- Response Volumes
    nps_response_volume AS NPS_RESPONSE_VOLUME,
    ltr_volume AS LTR_VOLUME,

    -- NPS Breakdown percentages (Rounded to 2)
    ROUND((promoter_count::FLOAT / NULLIF(nps_response_volume, 0)) * 100, 2) AS "NPS Promoters %",
    ROUND((passive_count::FLOAT / NULLIF(nps_response_volume, 0)) * 100, 2) AS "NPS Passive %",
    ROUND((detractor_count::FLOAT / NULLIF(nps_response_volume, 0)) * 100, 2) AS "NPS Detractor %"
FROM
    WeeklyMetrics
ORDER BY
    FISCAL_WEEK_ID DESC;
