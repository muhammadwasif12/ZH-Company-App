<p align="center">
  <img src="assets/logo/outer_app_logo.png" alt="ZH Company Logo" width="180" style="border-radius: 20px; box-shadow: 0 10px 25px rgba(0,0,0,0.3);" />
</p>

<h1 align="center">✨ ZH Company App ✨</h1>
<h3 align="center">Beon Cosmetic Order Management & Logistics ERP System</h3>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Framework-Flutter%203.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Language-Dart%203.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"></a>
  <a href="https://supabase.com"><img src="https://img.shields.io/badge/Backend-Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase"></a>
  <a href="https://cloudinary.com"><img src="https://img.shields.io/badge/Storage-Cloudinary-3448C5?style=for-the-badge&logo=cloudinary&logoColor=white" alt="Cloudinary"></a>
  <a href="#"><img src="https://img.shields.io/badge/Version-1.0.1-E5A93C?style=for-the-badge" alt="Version"></a>
  <a href="#"><img src="https://img.shields.io/badge/Status-Production%20Ready-4CAF50?style=for-the-badge" alt="Status"></a>
</p>

---

## 📖 Overview

**ZH Company App** is an enterprise-grade, ultra-premium order management and logistics ERP system tailored for **Beon Cosmetic**. Built with **Flutter**, **Riverpod**, **Supabase**, and **Cloudinary**, it provides seamless real-time inventory management, order processing, commission calculation, and financial ledger analytics.

The application supports dual operational modes (**Admin Panel** and **Staff Panel**), ensuring administrative control while providing operational tools for staff members to process orders efficiently.

---

## ✨ Key Features & Capabilities

### 🛡️ 1. Multi-Role Security & Biometric Lock
- **Role-Based Routing:** Automated navigation based on user roles (`Admin` vs `Staff`).
- **Biometric Security:** Integrated fingerprint / face unlock and PIN lock using `local_auth` and persistent secure preference storage.
- **Safe Staff Removal:** Deleting staff accounts safely soft-links historical orders, ensuring zero loss of revenue logs or admin dashboard statistics.

### 📦 2. Smart Order Management Lifecycle
- **Real-Time Order Tracking:** Create, edit, search, filter, and track orders across all operational stages:
  - `Pending` ➔ `Confirmed` ➔ `Shipped` ➔ `Delivered` ➔ `Returned` ➔ `Cancelled`
- **Courier Integration:** Custom courier tracking, city tagging, and automated delivery charge calculations.
- **Draft Auto-Save:** Active form inputs are saved as local drafts to prevent data loss.

### 🖼️ 3. Cloudinary Proof & Receipt System
- **Automated Image Uploads:** Seamlessly upload payment receipts or delivery proof images directly to Cloudinary.
- **SHA-1 Authenticated Cleanup:** Automatically deletes proof images from Cloudinary servers upon order deletion using secure HMAC SHA-1 signature hashing.

### 💰 4. Staff Salary & Commission Engine
- **Automated Calculations:** Calculates staff monthly earnings using the rule:
  $$\text{Final Salary} = \text{Total Delivered Commission} - \text{Total Return Penalty}$$
- **Flexible Models:** Supports both **Fixed Amount per Order** (e.g., Rs. 100/delivered order) and **Percentage on COD** (e.g., 10% of order total), with custom per-order return penalties.

### 📊 5. Financial COD Ledger & Analytics
- **Revenue Overview:** Interactive graphs (`fl_chart`) displaying daily, weekly, and monthly revenue metrics.
- **Cash-on-Delivery (COD) Tracking:** Monitors pending cash collection, courier settlements, and net profits.

### 📄 6. Thermal Printing & PDF Reports
- **Invoice Generation:** Generate formatted PDF invoices and delivery notes (`pdf`, `printing`).
- **Data Export:** Export order lists and financial statements directly to CSV/Excel formats for external accounting.

---

## 🏗️ Technology Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | [Flutter 3.x](https://flutter.dev) | Cross-platform UI compilation |
| **Language** | [Dart 3.x](https://dart.dev) | Null-safe, robust code execution |
| **State Management** | [Riverpod](https://riverpod.dev) | Reactive, scalable state management |
| **Database & Auth** | [Supabase](https://supabase.com) | PostgreSQL DB, Auth, Realtime listeners |
| **Media Hosting** | [Cloudinary](https://cloudinary.com) | Image hosting & secure signature deletion |
| **Charts & UI** | [fl_chart](https://pub.dev/packages/fl_chart) / Google Fonts | Data visualization & modern typography |
| **Security** | `local_auth` / `crypto` | Biometric lock & SHA-1 signature hashing |

---

## 📁 Directory Structure

```gcode
lib/
├── app.dart                    # Application root setup & router
├── main.dart                   # Environment initialization & entrypoint
├── core/
│   ├── constants/              # Colors, spacing, typography & Supabase keys
│   ├── services/               # Supabase, Cloudinary, Export & Security services
│   ├── theme/                  # Premium dark/light themes
│   └── widgets/                # Reusable UI components & Sidebar
├── features/
│   ├── auth/                   # Authentication & biometric lock screens
│   ├── cod_ledger/             # Financial ledger & cash collection screen
│   ├── dashboard/              # Admin overview dashboard & charts
│   ├── orders/                 # Order list, form, draft, & detail screens
│   ├── products/               # Inventory & stock threshold management
│   ├── reports/                # PDF & CSV reporting engines
│   ├── salary/                 # Staff salary & commission calculator
│   ├── settings/               # System configurations & courier settings
│   └── staff/                  # Staff account management
├── models/                     # Data models (Order, Product, Staff, User)
└── panels/                     # Dedicated Admin & Staff navigation panels
```

---

## ⚡ Setup & Local Development Guide

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>=3.3.0`)
- [Android Studio](https://developer.android.com/studio) or VS Code with Flutter extension
- Supabase project credentials & Cloudinary account details

### 1. Clone the Repository
```bash
git clone https://github.com/muhammadwasif12/ZH-Company-App.git
cd ZH-Company-App
```

### 2. Configure Environment Variables
Create a `.env` file in the root directory (never commit this file to public repos):
```env
SUPABASE_URL=https://your-supabase-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Run Locally
```bash
flutter run
```

---

## 📦 Building Production Release

### Option A: Universal Release APK (Recommended for all Android phones)
Generates a single installer compatible with all device architectures:
```bash
flutter build apk --release
```
> **Output:** `build/app/outputs/flutter-apk/app-release.apk`

### Option B: Split Per-ABI Release APKs (Optimized file size)
Generates separate lightweight APKs tailored for arm64-v8a, armeabi-v7a, and x86_64:
```bash
flutter build apk --release --split-per-abi
```
> **Output:** `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

## 🔒 Security & Privacy

- All secret API keys and database tokens are kept strictly in `.env` and `local.properties`.
- Comprehensive `.gitignore` rules ensure no environment files, keystores, or build artifacts are exposed in version control.

---

<p align="center">
  Developed with ❤️ for <b>Beon Cosmetic / ZH Company</b>
</p>
