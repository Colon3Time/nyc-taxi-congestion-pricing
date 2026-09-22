# NYC Taxi · Congestion Pricing Pipeline

End-to-end ELT pipeline on **real NYC TLC Yellow Taxi trip records (2024-01 → 2026-07, ~116M rows)**, built to answer a real policy question and validated against TLC's official monthly reports.

> 🚧 Work in progress

## Scenario

I'm the first Analytics Engineer on the TLC data team. Three stakeholders have sent requests.
New trip files are published monthly. Data must refresh within 24 hours of a new file, and headline numbers must match TLC's official monthly report within **1%**.

The scenario is role-play. Every event and dataset below is real.

## Business questions

### 1. Policy: Congestion Pricing impact (core)
New York started **Congestion Pricing** in lower Manhattan on **5 Jan 2025**. Taxi trips carry a per-trip fee (`cbd_congestion_fee`).

- Did taxi trips into and out of the zone drop after the policy started?
- Did revenue per trip change?
- Which hours and days were hit hardest?

### 2. Operations: Airport dispatch (JFK / LaGuardia)
- How many cabs should wait at each airport, by day of week and hour?
- Which zones do airport passengers go to most?

### 3. Data Governance: Can we trust the data? (runs alongside every step)
- What % of trips each month are invalid (negative fares, zero distance, dropoff before pickup)?
- Which vendor (`VendorID`) sends bad records most often?
- Do our numbers reconcile with TLC's official monthly report?

## Data sources

| Source | What | Link |
|---|---|---|
| Yellow Taxi Trip Records | 1 row per trip, monthly parquet | https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page |
| Taxi Zone Lookup | LocationID → Borough / Zone | https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv |
| TLC Monthly Data Reports | Official aggregates (**answer key** for validation) | https://www.nyc.gov/site/tlc/about/aggregated-reports.page |
| Data Dictionary | Column definitions and valid values | https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf |

Raw files are not committed (~1.9 GB). File URL pattern:
`https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`

**Known schema drift:** column count changes across the period (19 → 20 → 21 columns).

## Stack & versions

Versions are pinned here so the project can be rebuilt with the same tools. The table is updated whenever a new tool is added.

| Tool | Version | Used for | Runs on |
|---|---|---|---|
| Ubuntu | 24.04.4 LTS | Dev environment | Cloud VM (1 vCPU / 2 GB RAM) |
| DuckDB CLI | 1.5.5 | Step 0: explore raw parquet files | VM |
| Python | 3.12.3 | Step 1: extract & load | VM |
| Google Cloud SDK (`bq`) | 581.0.0 | BigQuery access | VM |
| BigQuery | Paid (budget alert 150 THB/month) · project `nyc-taxi-de-amorntep` · datasets `raw` / `dev` / `prod` (US) | Data warehouse | Google Cloud |
| git | 2.43.0 | Version control | VM |
| dbt | *TBD (step 2)* | Transform & test | VM |
| Airflow (Docker) | *TBD (step 6)* | Orchestration | Windows PC (VM RAM too small) |
| Looker Studio | n/a (web) | Dashboard | Browser |

## Project layout

```
data/
  raw/yellow/     monthly parquet files (gitignored)
  reference/      zone lookup + TLC official monthly report
docs/             design notes, decisions
```
