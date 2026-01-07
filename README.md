# CXCAT-3348-Weekly-VoC-Aggregate-Table-Query
This query is used for the CX WBR visual for the Owners Survey slide. Business Owner is Adam McCord

# Weekly VoC Aggregate Table Query (CXCAT-3348)

## 📌 Project Overview
This repository contains the SQL logic to generate a high-performance aggregate table for the **Weekly Business Report (WBR)**. It focuses on Net Promoter Score (NPS) and Likelihood to Repurchase (LTR) metrics sourced from the Owners Survey.

By moving from a dynamic view to a physical table (`CX_VOC_WEEKLY_REPORT_OWNERS_SURVEY_SCORES`), we provide a faster, more stable "Live" data source for Tableau.

## 🚀 Execution Instructions for Adam
> **Frequency:** Every Monday Morning (until productionalized).

1.  **Run Query:** Execute the script provided in `weekly_voc_aggregate.sql` within Snowflake.
2.  **Tableau Refresh:** Once the Snowflake query completes, go into your Tableau Desktop/Server application and refresh the data source.
3.  **Verification:** Ensure the data shows the last 12 full completed weeks (excluding the current partial week).

## 🛠 Next Steps (Production Goals)
- **Data Engineering:** Coordinate with the DE team to automate this table load (via Snowflake Task or Airflow) to run every Sunday/Monday.
- **Stakeholder Alignment:** Sync with **Josh and Sascha** to ensure metrics align with their expectations for the `Owners_Survey_Corp` view.
- **Expansion:** If new dimensions (like Product Line or Region) are required, contact **Jeremiah** for sourcing.

## 📊 Logic Details
- **Scope:** Last 12 full completed fiscal weeks (Logic: `DENSE_RANK BETWEEN 2 AND 13`).
- **Rounding:** All numerical outputs are rounded to **2 decimal places** for clean reporting in Tableau.
- **Metrics Included:**
    - Weekly NPS & Rolling 4-Week NPS
    - Weekly LTR & Rolling 4-Week LTR
    - Response Volumes (NPS & LTR)
    - NPS Category Breakdowns (%)

## 📂 Repository Structure
- `weekly_voc_aggregate.sql`: The primary table creation script.
- `README.md`: Project documentation and instructions.

---
**Lead Developer:** Jeremiah King
**Business Owner:** Adam McCord

## 🚦 Data Lifecycle & Deployment
To follow team best practices, this project uses a two-stage deployment:

1. **Phase 1 (Current):** Data is generated in the **DEV** schema:
   `CX_ANALYTICS_DEV.JEREMIAH_DEV_EXPLORATORY`
2. **Phase 2 (Target):** Data Engineering will migrate the logic to the **PROD** schema:
   `CX_ANALYTICS.CX_MODELS`

**Note to Business Owner:** Once Phase 2 is complete and the table is automated, the version in the DEV folder will be deprecated.
