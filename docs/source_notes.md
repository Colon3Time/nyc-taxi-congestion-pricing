# Source notes — NYC TLC Yellow Taxi

บันทึกการสำรวจต้นทางก่อนโหลดเข้าคลัง (ขั้น 0 ของ `PLAN.md`)
ขอบเขต: `data/raw/yellow/yellow_tripdata_YYYY-MM.parquet` 31 ไฟล์ (2024-01 → 2026-07)

## Schema changes (0.1 · สำรวจ 23 ก.ย. 69)

ใช้ DuckDB อ่านเฉพาะส่วนหัวของไฟล์ ไม่ได้อ่านข้อมูลจริง

```sql
SELECT name, count(*) AS files, min(regexp_extract(file_name,'\d{4}-\d{2}')) AS first_month
FROM parquet_schema('data/raw/yellow/*.parquet') GROUP BY name ORDER BY files;
```

### รายการคอลัมน์ทั้งหมด (21 ตัว — ไฟล์ล่าสุด 2026-07 มีครบทุกตัว, ไฟล์ 2024 มี 19 ตัว)

ช่อง "ความหมาย" เว้นไว้เติมตอนอ่าน Data Dictionary (0.2)

| # | คอลัมน์ | ชนิด | มีในกี่ไฟล์ | ความหมาย |
|---|---|---|---|---|
| 1 | `VendorID` | integer | 31 | |
| 2 | `tpep_pickup_datetime` | timestamp | 31 | |
| 3 | `tpep_dropoff_datetime` | timestamp | 31 | |
| 4 | `passenger_count` | bigint | 31 | |
| 5 | `trip_distance` | double | 31 | |
| 6 | `RatecodeID` | bigint | 31 | |
| 7 | `store_and_fwd_flag` | varchar | 31 | |
| 8 | `PULocationID` | integer | 31 | |
| 9 | `DOLocationID` | integer | 31 | |
| 10 | `payment_type` | bigint | 31 | |
| 11 | `fare_amount` | double | 31 | |
| 12 | `extra` | double | 31 | |
| 13 | `mta_tax` | double | 31 | |
| 14 | `tip_amount` | double | 31 | |
| 15 | `tolls_amount` | double | 31 | |
| 16 | `improvement_surcharge` | double | 31 | |
| 17 | `total_amount` | double | 31 | |
| 18 | `congestion_surcharge` | double | 31 | |
| 19 | `Airport_fee` | double | 31 | |
| 20 | `cbd_congestion_fee` | double | **19** (ตั้งแต่ 2025-01) | |
| 21 | `request_source` | varchar | **2** (ตั้งแต่ 2026-06) | |

### คอลัมน์ที่มีไม่ครบทุกเดือน

| คอลัมน์ | มีในกี่ไฟล์ | เริ่มเดือน | หมายเหตุ |
|---|---|---|---|
| `request_source` | 2 / 31 | 2026-06 | เพิ่งเพิ่มล่าสุด ยังไม่ทราบความหมาย → รอข้อ 0.2 |
| `cbd_congestion_fee` | 19 / 31 | 2025-01 | ตรงกับวันเริ่มนโยบาย Congestion Pricing (5 ม.ค. 2025) |

คอลัมน์ที่เหลือ 19 ตัวมีครบทั้ง 31 ไฟล์

> หมายเหตุ: แถวชื่อ `schema` ที่ได้จาก `parquet_schema` ไม่ใช่คอลัมน์จริง เป็นโหนดหัวของโครงสร้างไฟล์ parquet

### ชื่อคอลัมน์ไม่เป็นรูปแบบเดียวกัน

ใช้ปนกันภายในตารางเดียว
- แบบขึ้นต้นตัวใหญ่: `VendorID`, `RatecodeID`, `PULocationID`, `DOLocationID`, `Airport_fee`
- แบบตัวเล็กคั่นขีดล่าง: `trip_distance`, `fare_amount`, `payment_type`, ...

### ชนิดข้อมูล (ไฟล์ 2024-01)

จำนวนเต็มใช้ปนกันสองชนิด: `integer` (VendorID, PULocationID, DOLocationID) กับ `bigint` (passenger_count, RatecodeID, payment_type)

### สิ่งที่ต้องตัดสินใจ (ยกไปทำในขั้นต่อไป)

| # | เรื่อง | ทางเลือก | ตัดสินตอน |
|---|---|---|---|
| D1 | เดือนก่อน 2025-01 ไม่มี `cbd_congestion_fee` | เติมเป็น **NULL** (แปลว่า "ยังไม่มีนโยบายนี้") หรือเติม **0** (แปลว่า "มีนโยบายแล้วแต่เที่ยวนี้ไม่เสียเงิน") — ความหมายต่างกัน มีผลต่อโจทย์ 1 โดยตรง | A1 |
| D2 | เดือนก่อน 2026-06 ไม่มี `request_source` | เหมือน D1 แต่ต้องรู้ความหมายก่อน | A1 |
| D3 | ชื่อคอลัมน์สองรูปแบบ | เปลี่ยนเป็น snake_case ทั้งหมดในชั้น staging | A2 |
| D4 | จำนวนเต็มสองชนิด | แปลงให้เป็นชนิดเดียวกันตอนโหลด | A1/A2 |

---

_หัวข้อถัดไปจะเพิ่มเมื่อทำถึงส่วนนั้น_
