# Week-8-Assignment-Final-Project-Database
Clinic Booking & Management System – Database Schema
📌 Overview

This project implements a relational Clinic Booking & Management System in MySQL. It is designed to manage patients, doctors, appointments, medical records, billing, and payments in a small-to-medium clinic.

The database follows relational principles with primary keys, foreign keys, unique constraints, and check constraints to ensure data integrity.

📂 Database Schema
1. Users & Roles

users: Stores system users (admins, receptionists, doctors, nurses, accountants).

Ensures unique usernames and supports role-based access.

2. Patients & Addresses

patients: Patient demographic info.

addresses: One-to-many relation with patients (a patient may have multiple addresses).

3. Doctors & Specialties

doctors: Doctor profiles (linked to users if they log in).

specialties: List of medical specialties (e.g., Pediatrics, Dermatology).

doctor_specialties: Many-to-many bridge between doctors and specialties.

4. Appointments & Services

appointments: Core booking entity (patient + doctor + room + time).

services: Consultation/procedure types with duration and price.

appointment_services: Many-to-many mapping between appointments and services.

5. Medical Records & Prescriptions

medical_records: Stores diagnoses, vitals, and visit notes linked to patients and appointments.

prescriptions: Linked to medical records.

prescription_items: Medications prescribed in each prescription.

6. Billing & Payments

invoices: Bills linked to patients (and optionally appointments).

invoice_items: Line items with quantities and unit prices.

payments: Tracks payments received against invoices.

7. Clinic Resources

clinic_rooms: Consultation/treatment rooms.

🔑 Relationships

1-to-Many

Patient → Addresses

Doctor → Appointments

Appointment → Medical Records

Many-to-Many

Doctors ↔ Specialties

Appointments ↔ Services

1-to-1 (Optional)

Appointment ↔ Medical Record (per visit record)