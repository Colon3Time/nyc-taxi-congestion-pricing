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
- ขั้น S: Setup Google Cloud (ด้านล่าง)

## ✅ ตัดสินใจแล้ว (22 ก.ย.): ทำ 2 แบบ Local + Cloud

| | **A. Local** | **B. Cloud** |
|---|---|---|
| Warehouse | DuckDB (ไฟล์ `warehouse/nyc_taxi.duckdb` ในเครื่อง) | BigQuery project `nyc-taxi-de-amorntep` |
| ข้อมูล | ครบ 31 เดือน | ครบ 31 เดือน |
| raw | โหลดเข้าตารางใน DuckDB ทีละเดือน | **ไม่ copy เข้า BigQuery**: เก็บ parquet ใน GCS แล้วสร้าง External Table |
| fact | `fact_trip` รายเที่ยว + `fact_trip_hourly` แบบสรุป | `fact_trip_hourly` อย่างเดียว (aggregate fact) |
| ขีดจำกัด | ดิสก์ว่าง 30GB · RAM 2GB | **พื้นที่ BigQuery ≤ 8GB** (ฟรี 10GB/เดือน) → ค่าใช้จ่าย ≈ 0 |
| ได้ฝึก | SQL/dbt เต็มรูปแบบ, DML (DELETE+INSERT), ลองผิดลองถูกฟรี | Data Lake (GCS) + External Table, dev/prod, คุมต้นทุน cloud |

**ลำดับ:** ทำ A ให้เสร็จก่อน (ขั้น A1-A4) แล้วค่อยย้ายขึ้น B (ขั้น B1-B4)
- **dbt project เดียว 3 target:** `local` (DuckDB) · `dev` / `prod` (BigQuery)
- SQL ที่ต่างกันระหว่างสองที่ให้ใช้ macro ข้ามฐานข้อมูลของ dbt เช่น `dbt.date_trunc` / `dbt.datediff` ทักษะการย้าย warehouse นี้ใช้ในงานจริง

**ตัวเลขประมาณการ (ยังไม่ได้วัดจริง):**
- raw 116 ล้านแถวถ้าอยู่ใน BigQuery ≈ 18GB → จึงเก็บใน GCS แทน
- `fact_trip_hourly` ≈ หลักล้านแถว < 1GB
- query ผ่าน External Table นับรวมในโควตา 1TB ฟรี/เดือน · prod อ่านครบประมาณ 10-15GB ต่อรอบ

## ✅ ขั้น S: Setup Google Cloud (เสร็จ 22 ก.ย.)
- **Project:** `nyc-taxi-de-amorntep` (ชื่อ `nyc-taxi-de` ถูกใช้ไปแล้ว)
- **Billing:** ผูกกับ billing account เดิม
- **Budget alert:** **150 บาท/เดือน** (บัญชีคิดเงินเป็นบาท) เตือนเมื่อใช้ไป 50% / 90% / 100%
- **Dataset (US):** `raw` / `dev` / `prod`
- **Service account:** `pipeline` (BigQuery Data Editor + Job User)
- **Key:** `~/nyc-taxi-de-key.json` อยู่นอก repo · ทดสอบ query ผ่านแล้ว
- ยังต้องเพิ่มสิทธิ์ GCS ในขั้น B1

**dev vs prod (Cloud):**
- `dev` → อ่านแค่ 1-2 เดือน ใช้ตอนเขียนหรือแก้ model
- `prod` → อ่านครบ 31 เดือน รันเมื่อ model นิ่งแล้ว และให้ Airflow รัน

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

# ส่วน A: Local (DuckDB) ครบ 31 เดือน

## A1: Extract-Load เข้า DuckDB · ประมาณ 2 ช่อง
- **ทำ:** เขียน Python ที่รับเดือนเป็น parameter แล้วโหลดไฟล์ของเดือนนั้นเข้าตาราง `raw.yellow_trips` ใน `warehouse/nyc_taxi.duckdb`
  - รันเดือนเดิมซ้ำแล้วต้องไม่เบิ้ล (ฝึก **DELETE เดือนนั้น + INSERT ใหม่** ในหนึ่ง transaction)
  - ต้องจัดการ schema drift ที่จดไว้ในข้อ 0.1 (คอลัมน์ที่ไฟล์เก่าไม่มี)
  - ตั้ง `memory_limit` ของ DuckDB ไว้ต่ำกว่า RAM ที่เหลือ เพื่อไม่ให้เครื่องค้าง
- **สร้าง:**
  - `extract_load/load_month.py`
  - `requirements.txt`
  - ตาราง `raw.yellow_trips` + ตาราง `raw.load_log` (เดือน | แถวในไฟล์ | แถวที่โหลด | เวลาโหลด)
  - `warehouse/` ใส่ `.gitignore`
- **ดู:** ขนาดไฟล์ `.duckdb` หลังโหลดครบ และเวลาที่ใช้ต่อเดือน
- **ผ่านเมื่อ:**
  - แถวที่โหลดเท่ากับแถวในไฟล์ **ทุกเดือน**
  - รันเดือนเดิมซ้ำ 2 ครั้งแล้วแถวไม่เปลี่ยน

## A2: dbt staging (target `local`) · ประมาณ 2 ช่อง
- **ทำ:**
  - ติดตั้ง `dbt-duckdb` + `dbt-bigquery` ใน venv ของโปรเจกต์ + `dbt init`
  - ตั้ง `profiles.yml` ให้มี 3 target
  - ประกาศ source ชี้ไปที่ raw
  - ทำ staging: ชื่อคอลัมน์เป็น snake_case เหมือนกันทุกปี, แปลงชนิดข้อมูล, ใส่ **ธงแถวเสียแยกตามเหตุผล** (ไม่ลบทิ้ง)
- **สร้าง:** `dbt/profiles.yml`, `dbt/models/staging/_sources.yml`, `stg_yellow_trips.sql` (view), `_staging.yml` (test)
- **ตัดสินใจ:** กฎว่าอะไรนับเป็นแถวเสีย โดยใช้ผลจากข้อ 0.3
- **ผ่านเมื่อ:** `dbt build -s staging --target local` ผ่าน และแถวใน staging เท่ากับใน raw

## A3: dbt core (Data Warehouse) · ประมาณ 3 ช่อง
- **ทำ:** star schema
  - `fact_trip`: 1 แถวต่อเที่ยว เฉพาะแถวที่ดี (**local เท่านั้น**)
  - `fact_trip_hourly`: สรุปจาก `fact_trip` แยกตามชั่วโมง × โซนรับ × โซนส่ง × vendor × วิธีจ่ายเงิน × rate code (ใช้ทั้งสองแบบ)
  - `quarantine_trip`: แถวเสียพร้อมเหตุผล
  - dim ต่างๆ
- **สร้าง:**
  - `fact_trip.sql`, `fact_trip_hourly.sql`, `quarantine_trip.sql`
  - `dim_zone.sql`, `dim_date.sql`
  - seed CSV ของรหัสจากข้อ 0.2 (`vendor`, `ratecode`, `payment_type`)
  - `seeds/cbd_zones.csv`: โซนในเขตเก็บค่า congestion (ต้องหาแหล่งอ้างอิงทางการ)
- **ตัดสินใจ:** คอลัมน์ไหนเป็นมิติของ `fact_trip_hourly` และตัวเลขไหนต้องสรุป (count, sum, avg ต้องคิดให้ดี เพราะค่าเฉลี่ยรวมต่อไม่ได้)
- **ผ่านเมื่อ:**
  - test unique / not_null / relationships ผ่าน
  - fact + quarantine = staging
  - ผลรวมเที่ยวและรายได้ใน `fact_trip_hourly` เท่ากับใน `fact_trip`

## A4: Validation · ประมาณ 2 ช่อง
- **ทำ:**
  - โหลดรายงานทางการเป็น seed
  - `mart_reconciliation` เทียบเที่ยว/วัน, รายได้/วัน และนาที/เที่ยว กับของ TLC รายเดือน
  - `mart_data_quality` (โจทย์ 3)
  - ทั้งสอง mart ต้อง **สร้างจาก `fact_trip_hourly`** เพื่อให้ใช้บน cloud ได้ด้วย
- **สร้าง:** `seeds/tlc_monthly_report.csv`, `mart_reconciliation.sql`, `mart_data_quality.sql`, test ที่ล้มเมื่อต่างเกิน 1%
- **ผ่านเมื่อ:** ทุกเดือนต่างจากเฉลยไม่เกิน 1% หรือถ้าเกิน ต้องมีคำอธิบายจดไว้ใน `docs/`

**จบส่วน A = มี pipeline ครบในเครื่อง ← เริ่มยื่นสมัคร AE ได้**

---

# ส่วน B: Cloud (BigQuery ≤ 8GB)

## B1: Data Lake บน GCS · ประมาณ 1 ช่อง
- **ทำ:**
  - สร้าง bucket
    - **ต้องเช็คก่อนสร้าง:** GCS ให้ฟรี 5GB เฉพาะบาง region ของสหรัฐฯ และ BigQuery dataset `US` ต้องอ่าน bucket นั้นได้ (ยังไม่ได้ยืนยัน)
  - เพิ่มสิทธิ์ GCS ให้ service account
  - เขียน Python อัปโหลดไฟล์ parquet ทีละเดือน โดยวางโครง path เป็นแบบ `year=2025/month=01/`
- **สร้าง:** `extract_load/upload_to_gcs.py`, bucket + ไฟล์ 31 เดือน
- **ผ่านเมื่อ:** มีไฟล์ใน bucket ครบ 31 ไฟล์ ขนาดรวม ≈ 1.9GB

## B2: External Table · ประมาณ 1 ช่อง
- **ทำ:** สร้าง `raw.yellow_trips_ext` ให้อ่านไฟล์ใน GCS แบบ hive partition (กรองตามเดือนได้โดยไม่ต้องอ่านทุกไฟล์) และจัดการ schema drift
- **ดู:** query แต่ละครั้งอ่านข้อมูลกี่ GB (ดูได้จาก dry run) เปรียบเทียบระหว่างการกรองเดือนกับไม่กรอง
- **ผ่านเมื่อ:** นับแถวรายเดือนผ่าน External Table ได้เท่ากับตาราง raw ของ Local

## B3: ย้าย dbt ขึ้น BigQuery · ประมาณ 2 ช่อง
- **ทำ:**
  - รัน dbt ด้วย `--target dev` และแก้ SQL ที่ใช้ไม่ได้บน BigQuery ด้วย macro ข้ามฐานข้อมูล
  - ปิด `fact_trip` บน cloud (ใช้ `enabled` ตาม target)
  - staging เป็น view · `fact_trip_hourly` เป็น table แบ่ง partition รายเดือน
- **ผ่านเมื่อ:** `dbt build --target dev` ผ่าน แล้วตามด้วย `dbt build --target prod` ผ่าน

## B4: เทียบ Local กับ Cloud + คุมพื้นที่ · ประมาณ 1 ช่อง
- **ทำ:** เทียบตัวเลขใน `mart_reconciliation` ของสองที่ และดูพื้นที่รวมจาก `INFORMATION_SCHEMA.TABLE_STORAGE`
- **ผ่านเมื่อ:**
  - ตัวเลขสองที่ **ตรงกันทุกเดือน**
  - พื้นที่ BigQuery รวม **≤ 8GB**

## B5: Retention: ให้ cloud ลบข้อมูลเก่าเองเพื่อคุมไม่ให้เกิน 8GB · ประมาณ 1 ช่อง (ไอเดียผู้ใช้ 22 ก.ย.)
**หลักการ:**
- **Cloud** = เก็บเฉพาะข้อมูลดิบช่วงล่าสุด (rolling window) เมื่อเดือนใหม่เข้ามา เดือนเก่าสุดจะถูกลบออกอัตโนมัติ
- **Local** = คลังเก็บถาวร มีข้อมูลดิบครบทุกเดือน (ไม่มีต้นทุน)

**จุดที่ต้องระวัง:** ถ้าลบ raw ปี 2024 ออกจาก cloud ข้อมูล "ก่อนนโยบาย" ของโจทย์ 1 จะหายไปด้วย จึงแบ่งการเก็บเป็นสองชั้น
| ชั้น | เก็บบน Cloud นานแค่ไหน | เหตุผล |
|---|---|---|
| raw (parquet ใน GCS) | เฉพาะ N เดือนล่าสุด | ก้อนใหญ่ที่สุด ลบแล้วยังดึงใหม่จาก TLC หรือจาก Local ได้ |
| `fact_trip_hourly` + marts | **เก็บตลอด** | ก้อนเล็ก (< 1GB) และเป็นตัวที่ตอบโจทย์จริง |

**กฎสำคัญ:** ต้องสรุปเดือนนั้นเข้า `fact_trip_hourly` ให้เสร็จ **ก่อน** ลบ raw ของเดือนนั้นเสมอ

- **ทำ:**
  - ตัดสินใจเลข N จากขนาดจริงที่วัดได้ในขั้น B1/B4
  - ตั้งกลไกการลบ มี 2 ทางให้เลือกตอนถึงขั้นนี้:
    - **GCS lifecycle rule:** ลบไฟล์ตามอายุ
    - **ให้ DAG ลบเอง:** ลบหลังยืนยันว่าสรุปเดือนนั้นแล้ว (ปลอดภัยกว่า)
  - เพิ่ม check ที่ **ล้ม pipeline ถ้าพื้นที่รวมเกิน 8GB**
- **สร้าง:** `extract_load/apply_retention.py` (หรือเป็น task ใน DAG) และส่วน "Retention policy" ใน `docs/decisions.md`
- **ผ่านเมื่อ:**
  - ทดลองเพิ่มเดือนใหม่ 1 เดือนแล้วเดือนเก่าสุดถูกลบเอง
  - `fact_trip_hourly` ยังมีครบทุกเดือน
  - พื้นที่รวม ≤ 8GB

---

# ส่วนที่ทำหลังจบ A + B

## ขั้น 5: Marts ตอบโจทย์ · ประมาณ 2 ช่อง
- **สร้าง:** (จาก `fact_trip_hourly` จึงรันได้ทั้งสองที่)
  - `mart_congestion_impact`: ก่อน/หลัง 5 ม.ค. 2025 แยกตามโซน × ชั่วโมง
  - `mart_airport_dispatch`: สนามบิน × วันในสัปดาห์ × ชั่วโมง
- **ผ่านเมื่อ:** ตอบคำถามในโจทย์ 1 และ 2 ได้ด้วย query ง่ายๆ บน mart

## ขั้น 6: Airflow (บน PC Windows) · ประมาณ 2 ช่อง
- **ทำ:** ติดตั้ง Docker Desktop บน PC แล้วเขียน DAG รายเดือนให้ Cloud
  - เช็คว่ามีไฟล์เดือนใหม่ → อัปโหลด GCS → `dbt build --target prod` → validate → **retention: ลบ raw เดือนเก่าสุด + เช็คพื้นที่ ≤ 8GB** → แจ้งเตือนถ้าล้ม
- **สร้าง:** `airflow/dags/tlc_monthly.py`, `airflow/docker-compose.yml`
- **ผ่านเมื่อ:** DAG รันจบเองได้ 1 รอบใน Airflow UI (เก็บ screenshot ไว้ใส่ README)

## ขั้น 7: Dashboard + Portfolio · ประมาณ 2 ช่อง
- **สร้าง:**
  - Looker Studio ที่ต่อกับ mart บน BigQuery prod
  - README ฉบับเต็ม: แผนภาพสถาปัตยกรรม Local vs Cloud, ผลที่ค้นพบ, ผล validation, ต้นทุนจริง
  - `docs/decisions.md`
- **ผ่านเมื่อ:** คนเปิด README แล้วเข้าใจภายใน 30 วินาทีว่าทำอะไร และพบอะไร

---

## Verification (ทั้งโปรเจกต์)
- **A1:** แถวใน raw เท่ากับแถวในไฟล์ parquet ทุกเดือน และรันซ้ำไม่เบิ้ล
- **A3:** fact + quarantine = staging · ผลรวมใน hourly เท่ากับใน fact
- **A4:** ต่างจากรายงานทางการไม่เกิน 1%
- **B4:** Local และ Cloud ได้ตัวเลขตรงกัน · BigQuery ≤ 8GB
- **B5:** เพิ่มเดือนใหม่แล้วเดือนเก่าถูกลบเอง · hourly ยังมีครบทุกเดือน · พื้นที่ ≤ 8GB
- **อื่นๆ:** `dbt build` ผ่านทุก target · DAG รันจบเองได้ 1 รอบ
