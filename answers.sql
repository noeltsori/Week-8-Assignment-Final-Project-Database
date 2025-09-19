-- clinic_db.sql
-- Clinic Booking & Management System (MySQL)
-- Drop database if exists and create fresh
DROP DATABASE IF EXISTS clinic_management;
CREATE DATABASE clinic_management
  CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
USE clinic_management;

-- ----------------------------------------------------------------
-- TABLE: users (system users: receptionists, admins)
-- ----------------------------------------------------------------
CREATE TABLE users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL, -- store hashed password only
  full_name VARCHAR(150) NOT NULL,
  role ENUM('admin','reception','doctor','nurse','accountant') NOT NULL DEFAULT 'reception',
  email VARCHAR(150) UNIQUE,
  phone VARCHAR(30),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_login DATETIME NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: patients
-- ----------------------------------------------------------------
CREATE TABLE patients (
  patient_id INT AUTO_INCREMENT PRIMARY KEY,
  national_id VARCHAR(50) UNIQUE, -- may be NULL if not provided
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  gender ENUM('male','female','other') DEFAULT 'other',
  date_of_birth DATE,
  phone VARCHAR(30),
  email VARCHAR(150),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  emergency_contact_name VARCHAR(150),
  emergency_contact_phone VARCHAR(30)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: addresses (one patient => many addresses)
-- ----------------------------------------------------------------
CREATE TABLE addresses (
  address_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  type ENUM('home','work','other') DEFAULT 'home',
  line1 VARCHAR(255) NOT NULL,
  line2 VARCHAR(255),
  city VARCHAR(100),
  county VARCHAR(100),
  postal_code VARCHAR(20),
  country VARCHAR(100),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: specialties (for doctors)
-- ----------------------------------------------------------------
CREATE TABLE specialties (
  specialty_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: doctors
-- ----------------------------------------------------------------
CREATE TABLE doctors (
  doctor_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL, -- optional link to users table
  license_number VARCHAR(100) UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(30),
  email VARCHAR(150),
  bio TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Doctors <-> Specialties (many-to-many)
CREATE TABLE doctor_specialties (
  doctor_id INT NOT NULL,
  specialty_id INT NOT NULL,
  PRIMARY KEY (doctor_id, specialty_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE,
  FOREIGN KEY (specialty_id) REFERENCES specialties(specialty_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: clinic_rooms
-- ----------------------------------------------------------------
CREATE TABLE clinic_rooms (
  room_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(100),
  location_description VARCHAR(255),
  capacity INT DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: services (types of consults / procedures)
-- ----------------------------------------------------------------
CREATE TABLE services (
  service_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  standard_duration_minutes INT NOT NULL DEFAULT 30,
  price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: appointments
-- - Each appointment is with one patient and optionally one doctor & room
-- - An appointment can include multiple services (M:N via appointment_services)
-- ----------------------------------------------------------------
CREATE TABLE appointments (
  appointment_id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_uuid CHAR(36) NOT NULL UNIQUE, -- for external refs
  patient_id INT NOT NULL,
  doctor_id INT NULL,
  room_id INT NULL,
  scheduled_start DATETIME NOT NULL,
  scheduled_end DATETIME NOT NULL,
  status ENUM('scheduled','confirmed','checked_in','in_progress','completed','cancelled','no_show') NOT NULL DEFAULT 'scheduled',
  created_by_user INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE SET NULL,
  FOREIGN KEY (room_id) REFERENCES clinic_rooms(room_id) ON DELETE SET NULL,
  FOREIGN KEY (created_by_user) REFERENCES users(user_id) ON DELETE SET NULL,
  CONSTRAINT chk_appointment_times CHECK (scheduled_end > scheduled_start)
) ENGINE=InnoDB;

-- Appointment services (many-to-many between appointments and services)
CREATE TABLE appointment_services (
  appointment_id INT NOT NULL,
  service_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  service_price DECIMAL(10,2) NOT NULL, -- snapshot of service price at booking/time
  PRIMARY KEY (appointment_id, service_id),
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: medical_records (one-to-one: one patient -> one active record row OR many records)
-- We'll model medical_records as many records per patient (visit notes), but
-- you can also enforce a primary "patient_summary" if desired.
-- ----------------------------------------------------------------
CREATE TABLE medical_records (
  record_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  appointment_id INT NULL,
  record_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  height_cm DECIMAL(6,2) NULL,
  weight_kg DECIMAL(6,2) NULL,
  diagnosis TEXT,
  notes TEXT,
  created_by INT NULL, -- user or doctor who created the record
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE SET NULL,
  FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: prescriptions (linked to medical_records)
-- ----------------------------------------------------------------
CREATE TABLE prescriptions (
  prescription_id INT AUTO_INCREMENT PRIMARY KEY,
  record_id INT NOT NULL,
  prescribed_on DATETIME DEFAULT CURRENT_TIMESTAMP,
  prescribed_by INT NULL,
  notes TEXT,
  FOREIGN KEY (record_id) REFERENCES medical_records(record_id) ON DELETE CASCADE,
  FOREIGN KEY (prescribed_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE prescription_items (
  prescription_item_id INT AUTO_INCREMENT PRIMARY KEY,
  prescription_id INT NOT NULL,
  medication_name VARCHAR(255) NOT NULL,
  dosage VARCHAR(100), -- e.g., "500 mg"
  frequency VARCHAR(100), -- e.g., "twice daily"
  duration_days INT,
  instructions TEXT,
  FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- TABLE: invoices & payments (billing)
-- ----------------------------------------------------------------
CREATE TABLE invoices (
  invoice_id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT NULL,
  patient_id INT NOT NULL,
  invoice_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status ENUM('unpaid','partially_paid','paid','void') DEFAULT 'unpaid',
  created_by INT NULL,
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE SET NULL,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE invoice_items (
  invoice_item_id INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id INT NOT NULL,
  description VARCHAR(255),
  quantity INT NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  line_total DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) VIRTUAL,
  FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id INT NOT NULL,
  paid_on DATETIME DEFAULT CURRENT_TIMESTAMP,
  amount DECIMAL(10,2) NOT NULL,
  method ENUM('cash','card','mobile_money','insurance') DEFAULT 'cash',
  reference VARCHAR(255),
  received_by INT NULL,
  FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id) ON DELETE CASCADE,
  FOREIGN KEY (received_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Useful indexes for performance
-- ----------------------------------------------------------------
CREATE INDEX idx_patient_name ON patients(last_name, first_name);
CREATE INDEX idx_doctor_name ON doctors(last_name, first_name);
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX idx_appointments_start ON appointments(scheduled_start);

-- ----------------------------------------------------------------
-- Sample data.
-- ----------------------------------------------------------------

INSERT INTO users (username, password_hash, full_name, role, email) VALUES
('admin', 'HASHED_PASSWORD_PLACEHOLDER', 'Clinic Admin', 'admin', 'admin@clinic.test'),
('recept', 'HASHED_PASSWORD_PLACEHOLDER', 'Receptionist One', 'reception', 'frontdesk@clinic.test');

INSERT INTO specialties (name, description) VALUES
('General Practice','Primary care physician'),
('Pediatrics','Child health'),
('Dermatology','Skin specialist');

INSERT INTO doctors (user_id, license_number, first_name, last_name, phone, email) VALUES
(1, 'LIC-0001','Alice','Murithi','+254700000001','alice@clinic.test'),
(NULL, 'LIC-0002','John','Ouma','+254700000002','john@clinic.test');

INSERT INTO doctor_specialties (doctor_id, specialty_id) VALUES
(1,1),(1,2),(2,1);

INSERT INTO services (code, name, description, standard_duration_minutes, price)
VALUES
('CONS-GP','General Consultation','Routine doctor consultation',30,10.00),
('CONS-PED','Pediatric Consultation','Consultation for children',30,12.00),
('SKIN-CRT','Skin Consultation','Skin-related consultation',30,15.00);


INSERT INTO patients (national_id, first_name, last_name, gender, date_of_birth, phone, email) VALUES
('12345678','Noel','Tumbo','male','1990-05-17','+254700000003','noel@gm.com');

INSERT INTO clinic_rooms (code, name) VALUES ('R101','Consult Room 1'),('R102','Consult Room 2');

-- Show all columns, types, keys, defaults, nullability
DESC services;

SELECT 
    TABLE_NAME, INDEX_NAME, COLUMN_NAME, NON_UNIQUE
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'clinic_management';

-- See all rows in the table
SELECT * FROM services;
-- ----------------------------------------------------------------
-- Notes on data model choices:
-- - appointments -> appointment_services models many-to-many relationship between appointments and services.
-- - doctors can have multiple specialties (doctor_specialties).
-- - medical_records are linked to appointments and patients; many records per patient allowed.
-- - invoices are created per patient and can optionally be linked to appointments.
-- - foreign keys use ON DELETE CASCADE or SET NULL sensibly to avoid orphaned data.
-- - CHECK constraint ensures scheduled_end > scheduled_start (MySQL 8.0+ supports CHECK).
-- ----------------------------------------------------------------

