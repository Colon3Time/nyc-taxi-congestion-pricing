-- ตั้งค่าเริ่มต้นเวลาเปิด DuckDB สำหรับโปรเจกต์นี้ (เรียกด้วยคำสั่ง nyc)
SET memory_limit='1GB';                                        -- กันเครื่อง RAM 2GB ค้าง
SET file_search_path='/home/amorntep/nyc-taxi-congestion-pricing';  -- อ้าง path สั้นๆ ได้โดยไม่ต้อง cd
