````markdown
# FoodLink Donation In-take System

A working **Flutter + Firebase** mobile application built for  
**CMPT 385 – Introduction to Software Engineering** (Group Project).

This app implements the Overall Design Document for the **FoodLink Donation In-take System** and provides a real-time donation intake and reporting workflow for **Volunteers**, **Store Donors**, and **Staff/Admin**. :contentReference[oaicite:0]{index=0}  

Current submission: **GitLab Release `Sprint_3`**.

---

## 👥 Project Team

**Group Name:** C.O.D.E. – *Create, Organize, Develop, Export*  

- **Jacob Loewen** – 626892 – jacob.loewen4@mytwu.ca  
- **Ratna Appasani** – 650811 – ranakoushik.appasan@mytwu.ca  
- **Divij Gupta** – 646839 – divijgupta07@gmail.com  
- **Lakshya Sai** – 639832 – lakshyayayaa@gmail.com  

Instructor: **Dr. Herbert Tsang**  
Teaching Assistant: **Samuel Leung**

---

## 🎯 Purpose & Scope

FoodLink supports the **Food Link Society**, a non-profit that redistributes surplus food in the Lower Mainland.

The system replaces the manual process of **handwritten notes, voice memos, and spreadsheets** with a mobile app that:

- lets volunteers quickly log each donation box (category + weight in kg),
- keeps all data in **Cloud Firestore**,
- and generates **reports** for staff to analyze donation patterns and support audits. :contentReference[oaicite:1]{index=1}  

---

## 👤 User Roles

The app supports three primary roles:

- **Volunteer**
  - Picks up food from donors.
  - Weighs and categorizes donations.
  - Logs donations through the mobile app.

- **Store Donor**
  - Provides surplus food.
  - Needs clear pickup schedules and confirmation workflow.

- **Staff / Admin**
  - Manages schedules, stores, and volunteers.
  - Reviews donation data and generates reports.

Each role has a dedicated login flow and dashboard; role-based navigation ensures that users only see screens relevant to them.

---

## ✨ Major Features (Sprint 3)

### 🧑‍🤝‍🧑 Volunteer Module

- Register, login, logout, and password reset (email-based).
- Volunteer dashboard with:
  - Upcoming pickup assignments.
  - Access to donation logging.
- Donation entry:
  - Select store and schedule.
  - Add one or more donation items (category, boxes, weight in kg, notes).
- View personal donation history.

### 🏬 Store / Donor Module

- Store registration and secure login.
- Store dashboard:
  - View upcoming pickup schedule.
  - Confirm readiness for a given pickup.
  - Update store contact and address.
- Basic view of recent store donations.

### 🧑‍💼 Staff / Admin Module

- Staff login and logout.
- **Admin Dashboard** with navigation cards for:
  - Manage schedules (create / edit / delete).
  - Manage stores.
  - Manage volunteers.
  - Coverage / analytics view.
  - Donation reports.
  - Manual donation entry.
  - Review & edit donations.
  - Delivery tracking.
  - Staff invites.
- **Donation Reports Dashboard**
  - Filter by store, volunteer, and date range.
  - Show record count, total kg, average kg per donation.
  - Breakdown cards:
    - By store (total weight, counts, averages).
    - By volunteer (total weight, counts, averages).
  - CSV export (copies data to clipboard).
- **Manual Donation Entry**
  - Choose store and date.
  - Optional volunteer info.
  - Enter total boxes, total kg, and notes.
  - Saved to the main `donations` collection with `createdManually = true`.
- **Edit Donation (Admin)**
  - Edit food type(s), boxes, kg, notes, and date.
  - Total boxes and kg recalculated.
- **Staff Invites**
  - Add staff invite emails to `staffInvites` collection.
  - Remove existing invites.

---

## 🧱 Architecture Overview

The implementation follows the layered architecture described in the Overall Design Document. :contentReference[oaicite:2]{index=2}  

### Flutter App Layers

- **App Shell**
  - Top-level `Scaffold`, routing, and navigation between dashboards.
  - Shared theming (background images + dark overlay + light cards).

- **UI Layer**
  - Screens and widgets for each role (login, dashboards, forms, lists).

- **Domain Logic**
  - Use-case logic such as:
    - record donation session,
    - create/update schedule,
    - confirm pickup/delivery,
    - generate and export reports.

- **Data Layer**
  - Repositories wrapping all Firebase access:
    - Firebase Authentication (email/password).
    - Cloud Firestore (users, stores, schedules, donations, staffInvites, etc.).
    - Cloud Storage (images, report exports – future use).

All modules interact with Firebase through the **Data Layer**, keeping UI and business logic decoupled from backend details.

---

## ☁️ Firebase Backend

- **Firebase Authentication**
  - Email/password accounts for volunteers, stores, and staff.
  - Role information stored in Firestore (`role` field).

- **Cloud Firestore**
  - Main operational database:
    - `users` – volunteer, store, admin profiles.
    - `stores` – store metadata and contact info.
    - `schedules` – pickup assignments linking stores and volunteers.
    - `donations` – donation entries (items, totals, notes, timestamps).
    - `staffInvites` – pre-approved staff emails.
    - `reportsIndex` – summary entries for monthly reports (future extension).

- **Cloud Storage**
  - Used for profile photos (design) and potential export files / attachments.

---

## 🗄 Firestore Schema (Logical – Simplified)

The implementation follows the logical schema defined in the design document. :contentReference[oaicite:3]{index=3}  

Key collections:

- `users/{uid}`
  - `role` ∈ {`volunteer`, `store`, `admin`}
  - `full_name`, `email`, `phone`, `home_region`, `created_at`, `updated_at`

- `stores/{store_id}`
  - `name`, `address`, `region`, `contact_email`, `contact_phone`
  - `approved`, `owner_uid`, `created_at`, `updated_at`

- `schedules/{schedule_id}`
  - `store_id`, `volunteer_id`
  - `start_time`, `end_time`
  - `readiness_confirmed`, `pickup_completed`, timestamps
  - `notes`, `created_by`, `created_at`, `updated_at`

- `donations/{donation_id}`
  - `volunteer_id`, `store_id`, optional `schedule_id`
  - `foodType` / `category`, `weightKg` / `totalKg`, `totalBoxes`
  - `createdManually`, `status`, `notes`, timestamps

- `staffInvites/{emailKey}`
  - `name`, `email`, `createdByEmail`, `createdAt`

(Additional details such as `revisions` and `reportsIndex` are documented in the Overall Design Document and may be partially or fully supported depending on sprint scope.)

---

## 🧪 Sprint / Release Mapping

The implementation roughly follows the **three-release plan** from the design:

- **Release / Sprint 1 – Authentication & Scheduling**
  - Volunteer and store login/registration.
  - Admin approvals and schedule management.

- **Release / Sprint 2 – Donation Logging & Review**
  - Multi-item donation entry, history views.
  - Staff review and edit of donation records.

- **Release / Sprint 3 – Reporting & Admin Tools (this submission)**
  - Donation reports dashboard with filters and aggregates.
  - Manual donation entry.
  - Staff invites management.
  - Improved theming and consistency across all screens.

GitLab **tag `Sprint_3`** marks the exact commit used for this final submission.

---

## 🛠 Tech Stack

- **Language / Framework:** Flutter (Dart)  
- **Backend:** Firebase  
  - Cloud Firestore  
  - Firebase Authentication (email/password)  
  - Firebase Storage  
- **Platform:** Android (tested on emulator / device)  

---

## 🚀 How to Run the App

### 1. Clone the Repository

```bash
git clone https://gitlab.com/twu8/2025-3-cmpt385-03.git
cd project_1
````

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

1. Create a Firebase project.

2. Enable:

    * **Email/Password Authentication**
    * **Cloud Firestore**
    * **Cloud Storage**

3. Download `google-services.json` and place it in:

   ```text
   android/app/google-services.json
   ```

4. Make sure the Android application ID matches the one registered in Firebase.

### 4. Run the Application

```bash
flutter run
```

Choose an Android emulator or physical device when prompted.

---

## ⚠️ Known Limitations / Future Work

* Offline caching and full sync conflict resolution are simplified.
* Some advanced analytics (trend charts, long-term donor performance) are documented but not fully implemented.
* iOS support is possible but not configured as part of this course prototype.

---

## 📚 Related Documents

* **Overall Design Document – FoodLink Donation In-take System** (Version 0.1)
  Contains detailed requirements, use-case diagrams, activity diagrams, class/sequence diagrams, data schema, and release plan for the system.

---

## 🔐 Test Accounts (Sample Logins)

If you prefer not to create new accounts, you can use these demo users:

### Admin / Staff
- Email: staff@gmail.com
- Password: Plmokn@2489

### Store / Donor
- Email: 2@gmail.com
- Password: 2@gmail.coM

### Volunteer
- Email: koushik@gmail.com
- Password: 123456789@aA

## 👤 Creating New Accounts

If you prefer to create your own accounts instead of using the test logins:

- **Volunteer:** Use the **“Volunteer login” → “Register”** option in the app.
- **Store / Donor:** Use the **“Store login” → “Register store”** flow.
- **Staff / Admin:** Staff accounts are created by the team via Firebase/Auth
  and optionally managed through the **Staff Invites** screen. For marking,
  please use the provided Admin test account above.



*FoodLink Donation In-take System – CMPT 385, Group C.O.D.E., Sprint_3 Release.*

```
```
