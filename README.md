## Medical Appointments No_show - SQL Data cleaning Project

### Project Overview

Missed medical appointments (no-shows) lead to wasted resources, longer patient wait times, and reduced quality of healthcare delivery.

In this project, I used SQL as the primary tool to clean, transform, and analyze the Medical Appointment No-Show dataset.
The goal was to ingest, clean, and prepare a real-world healthcare dataset using MySQL, producing an analysis-ready dataset and uncover early insights that could help healthcare providers reduce no-show rates.

### Dataset Overview
The dataset contains patient appointment records, including:

- Appointment dates
- Demographics
- Health conditions
- SMS reminders
- Attendance outcome (No-Show)

### Data ingestion (Staging table)
Data Ingestion Challenge:
Encountered CSV encoding conflicts when importing into MySQL Workbench.
Resolved by bypassing the GUI import tool and loading data via LOAD DATA INFILE into a staging table, followed by SQL-based data cleaning and type conversion.

### Initial Data Exploration
- Verified row count (110,527 records)
- Checked column structure and sample records
- Confirmed successful ingestion

### Date cleaning & conversion

- Identified ISO-8601 date strings containing T and Z
- Cleaned strings and converted them into DATETIME
- Created new datetime columns(appointment_datetime & scheduled_datetime) to preserve raw data

All records were succssfully converted

### Scheduling Validation

Identified cases where appointments occurred before scheduling

Flagged invalid records instead of deleting them preserve data integrity while allowing flexible filtering in BI tools.

### Feature Engineering

Created:
- waiting_days using date difference
  
Added analytical flags:
- sms_received_flag
- no_show_flag

### Data Quality Checks
- Checked for missing values across all columns
- Performed age sanity checks (removed invalid record)
- Standardized inconsistent categorical values (e.g. handicap)

### Clean Table Creation
A fully typed table (medical_appointments) was created with:

- Correct numeric types
- Clean datetime fields
- Flags for analysis
- Primary key on appointment_id

### Export for Visualization
The cleaned dataset was exported and loaded into Power BI for dashboard development.

### Key Learnings:
- To safely ingest high-volume, bulk data, use LOAD DATA INFILE
- Discovered how to toggle SQL_SAFE_UPDATES to allow for running UPDATE and DELETE statements when a primary key and WHERE clause are not used
- Flagging issues is often better than deleting records
- SQL is powerful for preprocessing before visualization

### Next Steps

-  Build an interactive Power BI dashboard
- Explore additional healhcare dataset

### Tools Used
- MySQL
- Power BI
- Excel (Initial inspection).
