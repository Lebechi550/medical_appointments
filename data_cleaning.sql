-- Schema setup
USE hng; 

-- staging table to safely ingest raw csv data
-- All columns stored as VARCHAR to avoid type conflicts
CREATE TABLE staging_medical_appointments (
    PatientId VARCHAR(50),
    AppointmentID VARCHAR(50),
    Gender VARCHAR(10),
    ScheduledDay VARCHAR(50),
    AppointmentDay VARCHAR(50),
    Age VARCHAR(10),
    Neighbourhood VARCHAR(100),
    Scholarship VARCHAR(10),
    Hypertension VARCHAR(10),
    Diabetes VARCHAR(10),
    Alcoholism VARCHAR(10),
    Handcap VARCHAR(10),
    SMS_received VARCHAR(10),
    No_show VARCHAR(10)
);

-- Data ingestion using LOAD DATA INFILE to bypass MySQL Workbench import limitations
LOAD DATA INFILE "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/medical_appointments_raw.csv"
INTO TABLE staging_medical_appointments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS; 

-- Confirm successful ingestion (Initial Data Exploration)

SELECT COUNT(*) AS total_records
FROM staging_medical_appointments; -- returned 110, 527 rows

SELECT *
FROM staging_medical_appointments
LIMIT 10;

DESCRIBE staging_medical_appointments;

/*
Data cleaning
Handle date column, ScheduledDay and AppointmentDay were strings (contained T & Z)
'2016-04-29T18:38:08Z', '2016-04-29T00:00:00Z'
Solution: created new DATETIME column foe both ScheduledDay and AppointmentDay, then cleaned strings before conversion
*/

ALTER TABLE staging_medical_appointments 
ADD COLUMN scheduled_datetime DATETIME,
ADD COLUMN appointment_datetime DATETIME;
-- ScheduledDay
UPDATE staging_medical_appointments
SET scheduled_datetime = STR_TO_DATE(
	REPLACE(REPLACE(ScheduledDay, 'T', ' '), 'Z', ' '),
    '%Y-%m-%d %H:%i:%s'
);
-- AppointmentDay
UPDATE staging_medical_appointments
SET appointment_datetime = STR_TO_DATE(
	REPLACE(REPLACE(AppointmentDay, 'T', ' '), 'Z', ' '),
    '%Y-%m-%d %H:%i:%s'
);  

-- Validation showed 0 failed conversion
SELECT
	SUM(CASE when scheduled_datetime IS NULL THEN 1 ELSE 0 END) AS wrong_schedule_dates,
    SUM(CASE WHEN appointment_datetime IS NULL THEN 1 ELSE 0 END) AS wrong_appointment_dates
FROM staging_medical_appointments; 

-- Scheduling integrity check
SELECT COUNT(*) AS wrong_scheduling_dates
FROM staging_medical_appointments
WHERE appointment_datetime < scheduled_datetime; -- 38,568 rows returned   
-- Decision: 
-- flag the invalid appointments
ALTER TABLE staging_medical_appointments
ADD COLUMN invalid_schedule_flag TINYINT DEFAULT 0;
-- Populate invalid_scheduled_flag
UPDATE staging_medical_appointments
SET invalid_schedule_flag = 1
WHERE appointment_datetime < scheduled_datetime;

-- Feature Engineering: waiting_days
ALTER TABLE staging_medical_appointments
 ADD COLUMN waiting_days INT;
 -- Populate waiting_days
 UPDATE staging_medical_appointments
 SET waiting_days = DATEDIFF(Appointment_datetime, scheduled_datetime);

-- Check for missing values in all the columns
SELECT
	SUM(CASE WHEN PatientID IS NULL THEN 1 ELSE 0 END) AS missing_patient_id,
  SUM(CASE WHEN APPOINTMENTID IS NULL THEN 1 ELSE 0 END) AS missing_appointment_id,
  SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS missing_gender,
  SUM(CASE WHEN Scheduled_datetime IS NULL THEN 1 ELSE 0 END) AS missing_scheduled_day,
  SUM(CASE WHEN Appointment_datetime IS NULL THEN 1 ELSE 0 END) AS missing_appointment_day,                      
  SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS missing_age,
  SUM(CASE WHEN Neighbourhood IS NULL THEN 1 ELSE 0 END) AS missing_neighbourhood,
  SUM(CASE WHEN Scholarship IS NULL THEN 1 ELSE 0 END) AS missing_scholarship,
  SUM(CASE WHEN Hypertension IS NULL THEN 1 ELSE 0 END) AS missing_htn,
	SUM(CASE WHEN Diabetes IS NULL THEN 1 ELSE 0 END) AS missing_diabetes,
	SUM(CASE WHEN Alcoholism IS NULL THEN 1 ELSE 0 END) AS missing_alcoholism,
	SUM(CASE WHEN Handcap IS NULL THEN 1 ELSE 0 END) AS missing_handicap,
	SUM(CASE WHEN SMS_received IS NULL THEN 1 ELSE 0 END) AS missing_sms,
	SUM(CASE WHEN No_show IS NULL THEN 1 ELSE 0 END) AS missing_no_show
FROM staging_medical_appointments; -- No missing values detected

-- Data Quality and sanity checks
SELECT *
FROM staging_medical_appointments
WHERE Age <0 OR Age > 120; -- 1 row returned
-- Delete invalid Age
DELETE 
FROM staging_medical_appointments
WHERE Age < 0 OR Age > 120;

-- Standardizing Categorical values

-- chcek for consistency in the values
SELECT DISTINCT Gender FROM staging_medical_appointments; -- consistent values F & M
SELECT DISTINCT Scholarship FROM staging_medical_appointments;  -- consistent values - 0 & 1      
SELECT DISTINCT Hypertension FROM staging_medical_appointments; -- consistent values 0 & 1
SELECT DISTINCT Diabetes FROM staging_medical_appointments; -- consistent values 0 & 1
SELECT DISTINCT Alcoholism FROM staging_medical_appointments; -- consistent values 0 & 1
SELECT DISTINCT Handcap FROM staging_medical_appointments; -- Inconsistent values 0,1, 2, 3, & 4
SELECT DISTINCT No_show FROM staging_medical_appointments; -- consistent values Yes & No

-- Handle the inconsistency in Handcap
UPDATE staging_medical_appointments
SET Handcap = 1
WHERE Handcap >1;

-- Rename "Handcap" to "Handicap"
ALTER TABLE staging_medical_appointments
RENAME COLUMN Handcap TO Handicap;

-- Rename again (Handicap to handicap)
ALTER TABLE staging_medical_appointments
RENAME COLUMN Handicap TO handicap;

-- Flag creation

-- Flag No_show appointments
ALTER TABLE staging_medical_appointments
ADD COLUMN no_show_flag TINYINT;
-- Populate the column(no_show_flag)
UPDATE staging_medical_appointments
SET no_show_flag = 
	CASE
		WHEN No_show = "Yes" THEN 1
        ELSE 0
        END;

-- Flag SMS_received
SELECT DISTINCT SMS_received FROM staging_medical_appointments;   
ALTER TABLE staging_medical_appointments
ADD COLUMN sms_received_flag TINYINT;
-- Populate the column(sms_received_flag)
UPDATE staging_medical_appointments
SET sms_received_flag = 
	CASE
		WHEN SMS_received = 1 THEN 1
        ELSE 0
        END;

-- Clean Table Creation
CREATE TABLE medical_appointments(
	appointment_id BIGINT PRIMARY KEY,
    patient_id BIGINT,
    gender VARCHAR(10),
    neighbourhood VARCHAR(70),
    age INT,
    scheduled_datetime DATETIME,
    appointment_datetime DATETIME,
    sms_received TINYINT,
    scholarship TINYINT,
    hypertension TINYINT,
    diabetes TINYINT,
    alcoholism TINYINT,
    handicap TINYINT,
    no_show VARCHAR(5),
	invalid_schedule_flag TINYINT,
	waiting_days INT,
    sms_received_flag TINYINT, 
    no_show_flag TINYINT
);                

-- Insert data into the clean table (medical_appointments)
INSERT INTO medical_appointments(
appointment_id,
    patient_id,
    gender,
    neighbourhood,
    age,
    scheduled_datetime,
    appointment_datetime,
    sms_received,
    scholarship,
    hypertension,
    diabetes,
    alcoholism,
    handicap,
    no_show,
	invalid_schedule_flag,
	waiting_days,
    sms_received_flag, 
    no_show_flag
)
SELECT
	CAST(AppointmentID AS SIGNED),
	CAST(PatientID AS SIGNED),
	Gender,
	Neighbourhood,
	CAST(Age AS SIGNED),
	scheduled_datetime,
	appointment_datetime,
	CAST(SMS_received AS SIGNED),
	CAST(Scholarship AS SIGNED),
	CAST(Hypertension AS SIGNED),
	CAST(Diabetes AS SIGNED),
	CAST(Alcoholism AS SIGNED),
	CAST(handicap AS SIGNED),
	No_show,
	invalid_schedule_flag,
	waiting_days,
	sms_received_flag,
	no_show_flag
FROM staging_medical_appointments;

-- New Table validation
select count(*) AS total_rows
FROM medical_appointments; -- matching rows (110,526 rows) returned
SELECT MIN(age), max(age)
FROM medical_appointments; -- minimum age = 0 and maximum age = 115

-- Add Constraints to maintain data intergrity. 
-- CHECK Constraints for realistic age
ALTER TABLE medical_appointments
ADD CONSTRAINT chk_age
CHECK (age BETWEEN 0 AND 120);

-- Add CHECK contraint on waiting_days to ensure that there is no negative values
ALTER TABLE medical_appointments
ADD CONSTRAINT chk_waiting_days
CHECK(
	invalid_schedule_flag = 1
    OR waiting_days >= 0
);

-- Add CHECK constraint to ensure that sms_received_flag is either 0 or 1.
ALTER TABLE medical_appointments
ADD CONSTRAINT chk_sms_received_flag
CHECK(sms_received_flag IN (0, 1));

-- Add CHECK constraint to ensure that no_show_flag is either 0 or 1.
ALTER TABLE medical_appointments
ADD CONSTRAINT chk_no_show_flag
CHECK(no_show_flag IN (0, 1));

-- Create Indexes to speed up data retrieval (patient_id, appointment_date, and no_show_flag)
CREATE INDEX idx_patient_id
ON medical_appointments (patient_id);

CREATE INDEX idx_appointment_date
ON medical_appointments (appointment_datetime);

CREATE INDEX idx_no_show_flag
ON medical_appointments (no_show_flag);

-- Index Validation
SHOW INDEX FROM medical_appointments;

-- CHECK Constraint Validation
SELECT *
FROM information_schema.table_constraints
WHERE table_name = 'medical_appointments';

-- Export the table - medical_appointment
SELECT * 
FROM medical_appointments;


