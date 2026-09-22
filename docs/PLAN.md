# แผนงาน: NYC Taxi · Congestion Pricing Pipeline

## Context
เปลี่ยนจากโปรเจกต์คิวร้านอาหาร (mock data) มาใช้ข้อมูลจริงของ TLC เพราะงานนี้เหมือนงาน DE จริง และมีเฉลยทางการไว้ตรวจงาน
Repo: `~/nyc-taxi-congestion-pricing/` → github.com/Colon3Time/nyc-taxi-congestion-pricing
**ผู้ใช้เขียนโค้ดเองทั้งหมด Claude ไกด์และรีวิวเท่านั้น** (Claude ทำเองได้แค่ติดตั้ง/setup/git/เอกสาร)
ข้อจำกัด: VM มี RAM 2GB · ทำได้วันละไม่เกิน 3 ช่อง

แต่ละขั้นเขียนไว้ 4 หัวข้อ:
- **ทำ:** ลงมือทำอะไร
- **สร้าง:** ไฟล์ไหนหรือตารางไหนเกิดขึ้น
- **ดู:** ต้องสังเกตหรือจดอะไร
- **ผ่านเมื่อ:** รู้ได้ยังไงว่าจบขั้นนี้แล้ว

---

## ✅ ที่ทำเสร็จแล้ว
- repo + README (โจทย์ 3 ข้อ, แหล่งข้อมูล, ตาราง Stack & versions)
- ข้อมูลดิบ 31 ไฟล์ใน `data/raw/yellow/` + ไฟล์อ้างอิง `data/reference/` (zone lookup, รายงานทางการ TLC)
- ติดตั้ง DuckDB 1.5.5 · ตัดสินใจแล้วว่า Airflow รันบน PC

## ✅ ตัดสินใจแล้ว: Data Warehouse = BigQuery แบบผูกบัตร + แยก dev/prod (22 ก.ย.)
- **เหตุผล:** sandbox จุได้แค่ 10GB แต่ข้อมูลรวม raw กับ fact ประมาณ 30-40GB (ประมาณการ) และบริษัทจริงใช้ cloud warehouse ที่จ่ายเงินพร้อมแยก dev/prod
- **ไม่ต้องผูกบัตรใหม่:** มี billing account `My Billing Account 1` เปิดใช้งานอยู่แล้ว
- **ค่าใช้จ่ายโดยประมาณ:** ~$1/เดือน (ประมาณการ) · ผู้ใช้ควรเช็คใน Console → Billing → Credits ว่ายังมีเครดิตฟรีเหลือไหม

## ✅ ขั้น S: Setup Google Cloud (เสร็จ 22 ก.ย.)

ผลจริง: project `nyc-taxi-de-amorntep` (ชื่อ `nyc-taxi-de` ถูกใช้ไปแล้ว) · ผูกบัตรแล้ว · budget alert **150 บาท/เดือน** (บัญชีคิดเงินเป็นบาท) · dataset `raw`/`dev`/`prod` ที่ US · service account `pipeline` + key ที่ `~/nyc-taxi-de-key.json` (ทดสอบ query ผ่านแล้ว)

| # | ทำ | ผลลัพธ์ |
|---|---|---|
| S1 | สร้าง project `nyc-taxi-de` (ถ้าชื่อซ้ำ ระบบจะเติมเลขต่อท้าย) | project ใหม่ แยกจากงานเก่า |
| S2 | ผูก project กับ `My Billing Account 1` | ไม่มีข้อจำกัดแบบ sandbox |
| S3 | ตั้ง budget alert 150 บาท/เดือน แจ้งเตือนเมื่อใช้ไป 50% / 90% / 100% | ส่งอีเมลเตือนก่อนค่าใช้จ่ายบานปลาย |
| S4 | เปิด BigQuery API | — |
| S5 | สร้าง 3 dataset ที่ location `US`: `raw` (ข้อมูลดิบ), `dev` (dbt ตอนพัฒนา), `prod` (dbt ของจริง) | โครง dev/prod แบบทีมจริง |
| S6 | สร้าง service account `pipeline` ให้สิทธิ์ BigQuery Data Editor + Job User · เก็บไฟล์ key ไว้ที่ `~/nyc-taxi-de-key.json` (**นอก repo**) | สคริปต์และ dbt ใช้ต่อ BigQuery |
| S7 | อัปเดตตาราง Stack & versions ใน README (BigQuery: paid, project `nyc-taxi-de`) | — |

**ผ่านเมื่อ:** `bq ls` เห็น dataset ครบ 3 ตัว และ `gcloud billing projects describe` แสดง `billingEnabled: true`

**dev vs prod ใช้ยังไง (ขั้น 2 เป็นต้นไป):**
- dbt target `dev` → เขียนลง dataset `dev` และอ่าน raw แค่ 1-2 เดือนล่าสุด (เร็วและถูก ใช้ตอนเขียนหรือแก้ model)
- dbt target `prod` → เขียนลง dataset `prod` และอ่านข้อมูลครบ 31 เดือน (รันเมื่อ model นิ่งแล้ว และให้ Airflow รัน)

---

## ขั้น 0: สำรวจต้นทาง (ใช้ DuckDB) · ประมาณ 2 ช่อง

**0.1 เทียบ schema ข้ามปี** ⏳ กำลังทำ
- **ทำ:** รัน `DESCRIBE` กับไฟล์ 2024-01, 2025-01, 2026-07
- **ดู:**
  - คอลัมน์ไหนเพิ่มมา และเพิ่มตั้งแต่เดือนไหน
  - ชื่อไหนสะกดหรือใช้ตัวพิมพ์ต่างกัน
  - ชนิดข้อมูลไหนเปลี่ยน
- **สร้าง:** หัวข้อ "Schema changes" ใน `docs/source_notes.md` เป็นตาราง: คอลัมน์ | 2024 | 2025 | 2026

**0.2 อ่าน Data Dictionary**
- **ทำ:** เปิด PDF ของ TLC (ลิงก์อยู่ใน README) แล้วอ่านทุกคอลัมน์
- **ดู:** รหัสทุกตัวที่ต้องแปลความหมาย เช่น `VendorID`, `RatecodeID`, `payment_type`, `store_and_fwd_flag` รวมถึงคอลัมน์ใหม่ที่เจอในข้อ 0.1
- **สร้าง:** หัวข้อ "Column dictionary" ใน `source_notes.md` (คอลัมน์ | ความหมาย | ค่าที่ถูกต้อง)
  - รหัสที่มีความหมายตายตัว → จดไว้เพื่อทำเป็น **seed CSV** ในขั้น 3 เช่น `seeds/payment_type.csv`

**0.3 ดูรูปร่างข้อมูล 1 เดือน (เลือก 2025-01)**
- **ทำ:** นับแถว, ดูค่า min/max ของตัวเลขและวันที่, นับค่าว่างต่อคอลัมน์, นับค่าที่ต่างกันของคอลัมน์รหัส
- **ดู:** ค่าที่ผิด dictionary เช่น
  - รหัสที่ไม่มีในเอกสาร
  - เงินติดลบ
  - ระยะทาง 0
  - เวลาส่งก่อนเวลารับ
  - **วันที่อยู่นอกเดือนของไฟล์** (เช่นมีเที่ยวปี 2008 ในไฟล์ปี 2025)
- **สร้าง:** หัวข้อ "Data quality observations" ใน `source_notes.md` (ปัญหา | ตัวอย่าง | จำนวนแถว | % ของเดือน)
  - ยังไม่ต้องตัดสินใจว่าจะแก้ยังไง ขั้น 2 ค่อยตัดสิน

**0.4 ดูตารางอ้างอิง**
- **ทำ:** เปิด `taxi_zone_lookup.csv` และ `tlc_data_reports_monthly.csv`
- **ดู:**
  - มีโซนกี่โซน มีโซน "Unknown" หรือไม่
  - รายงานทางการมีตัวเลขอะไรบ้างที่เอามาเทียบได้ และแต่ละตัวนิยามว่าอะไร
- **สร้าง:** หัวข้อ "Reference data" ใน `source_notes.md`

**ผ่านเมื่อ:** `docs/source_notes.md` มีครบ 4 หัวข้อ → commit

---

## ขั้น 1: Extract-Load เข้า BigQuery raw · ประมาณ 2-3 ช่อง

**ตัดสินใจก่อนเริ่ม:** วิธีกันข้อมูลซ้ำ (ทับทั้ง partition ของเดือนนั้น หรือใช้ MERGE ซึ่งใช้ได้แล้วหลังผูกบัตร) · ทำหลังขั้น S

- **ทำ:** เขียน Python ที่รับเดือนเป็น parameter แล้วโหลดไฟล์ parquet ของเดือนนั้นเข้า **partition ของเดือนนั้น** แบบทับของเดิม
  - รันซ้ำเดือนเดิมแล้วข้อมูลไม่เบิ้ล และไม่ต้องใช้ MERGE
  - ต้องจัดการ schema ที่เปลี่ยนไปตามที่จดในข้อ 0.1
- **สร้าง:**
  - `extract_load/load_month.py`
  - `requirements.txt`
  - `.env.example`
  - ตาราง `raw.yellow_trips` (partition รายเดือน)
  - ตาราง `raw.load_log` (เดือน | จำนวนแถวในไฟล์ | จำนวนแถวที่โหลด | เวลาโหลด)
- **ดู:** ขนาดตารางหลังโหลดเดือนแรก เพื่อประเมินพื้นที่ทั้งหมดจากตัวเลขจริง
- **ผ่านเมื่อ:**
  - จำนวนแถวที่โหลดเท่ากับจำนวนแถวในไฟล์ **ทุกเดือน**
  - รันเดือนเดิมซ้ำ 2 ครั้งแล้วจำนวนแถวไม่เปลี่ยน

## ขั้น 2: dbt staging · ประมาณ 2 ช่อง
- **ทำ:**
  - ติดตั้ง dbt-bigquery ใน venv ของโปรเจกต์ + `dbt init`
  - ประกาศ source ชี้ไปที่ raw
  - ทำ staging: ชื่อคอลัมน์เป็น snake_case เหมือนกันทุกปี, แปลงชนิดข้อมูล, ใส่ **ธงแถวเสียแยกตามเหตุผล** (ไม่ลบทิ้ง)
- **สร้าง:** `dbt/models/staging/_sources.yml`, `stg_yellow_trips.sql`, `_staging.yml` (test)
- **ตัดสินใจ:** กฎว่าอะไรนับเป็นแถวเสีย โดยใช้ผลจากข้อ 0.3
- **ผ่านเมื่อ:** `dbt build -s staging` ผ่าน และจำนวนแถวใน staging เท่ากับใน raw

## ขั้น 3: dbt core (Data Warehouse) · ประมาณ 3 ช่อง
- **ทำ:** star schema
  - `fact_trip`: 1 แถวต่อเที่ยว เก็บเฉพาะแถวที่ดี partition รายวัน
  - dim ต่างๆ ต่อกับ fact
  - แถวเสียแยกไปไว้ที่ `quarantine_trip` พร้อมเหตุผล
- **สร้าง:**
  - `fact_trip.sql`, `quarantine_trip.sql`
  - `dim_zone.sql`, `dim_date.sql`
  - seed CSV ของรหัสจากข้อ 0.2 (`vendor`, `ratecode`, `payment_type`)
  - `seeds/cbd_zones.csv`: รายชื่อโซนที่อยู่ในเขตเก็บค่า congestion
- **ตัดสินใจ:** grain ของ fact, วิธีระบุโซนในเขตเก็บเงิน (ต้องหาแหล่งอ้างอิงทางการ)
- **ผ่านเมื่อ:**
  - test เรื่อง unique / not_null / relationships ผ่าน
  - แถวใน fact + แถวใน quarantine = แถวใน staging

## ขั้น 4: Validation · ประมาณ 2 ช่อง ← จบขั้นนี้เริ่มยื่นสมัคร AE ได้
- **ทำ:**
  - โหลดรายงานทางการเป็น seed
  - ทำ mart เทียบเที่ยว/วัน, รายได้/วัน และนาที/เที่ยว ของเรากับของ TLC รายเดือน
  - ทำ mart คุณภาพข้อมูล (โจทย์ 3)
- **สร้าง:** `seeds/tlc_monthly_report.csv`, `mart_reconciliation.sql`, `mart_data_quality.sql`, test ที่ล้มเมื่อต่างกันเกิน 1%
- **ผ่านเมื่อ:** ทุกเดือนต่างจากเฉลยไม่เกิน 1% หรือถ้าเกิน ต้องมีคำอธิบายจดไว้ใน `docs/`

## ขั้น 5: Marts ตอบโจทย์ · ประมาณ 2 ช่อง
- **สร้าง:**
  - `mart_congestion_impact` (ก่อน/หลัง 5 ม.ค. 2025 แยกตามโซน × ชั่วโมง)
  - `mart_airport_dispatch` (สนามบิน × วันในสัปดาห์ × ชั่วโมง)
- **ผ่านเมื่อ:** ตอบคำถามในโจทย์ 1 และ 2 ได้ด้วย query ง่ายๆ บน mart

## ขั้น 6: Airflow (บน PC Windows) · ประมาณ 2 ช่อง
- **ทำ:** ติดตั้ง Docker Desktop บน PC แล้วเขียน DAG รายเดือน
  - เช็คว่ามีไฟล์เดือนใหม่ → โหลด → `dbt build` → validate → แจ้งเตือนถ้าล้ม
- **สร้าง:** `airflow/dags/tlc_monthly.py`, `airflow/docker-compose.yml`
- **ผ่านเมื่อ:** DAG รันจบเองได้ 1 รอบใน Airflow UI (เก็บ screenshot ไว้ใส่ README)

## ขั้น 7: Dashboard + Portfolio · ประมาณ 2 ช่อง
- **สร้าง:**
  - Looker Studio ที่ต่อกับ mart
  - README ฉบับเต็ม: แผนภาพสถาปัตยกรรม, ผลที่ค้นพบ, ผล validation
  - `docs/decisions.md`
- **ผ่านเมื่อ:** คนเปิด README แล้วเข้าใจภายใน 30 วินาทีว่าทำอะไร และพบอะไร

---


## Verification (ทั้งโปรเจกต์)
- ขั้น 1: แถวใน raw เท่ากับแถวในไฟล์ parquet ทุกเดือน และรันซ้ำแล้วไม่เบิ้ล
- ขั้น 3: fact + quarantine = staging
- ขั้น 4: ต่างจากรายงานทางการไม่เกิน 1%
- `dbt build` ผ่านทั้งหมด · DAG รันจบเองได้ 1 รอบ
