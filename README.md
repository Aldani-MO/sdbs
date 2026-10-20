# 🚌 SDBS — Smart Digital Bus System

A full-stack **Flutter + Firebase** mobile application for managing a smart public transit system. Built for passengers, drivers, and administrators — each with their own tailored dashboard and features.

---

## 📖 Project Overview

SDBS (Smart Digital Bus System) is a complete transit management platform designed to improve the public bus experience. The system connects **passengers**, **bus drivers**, and **transit administrators** in real time using Firebase's live database infrastructure.

The standout feature is a **capacity-aware decision engine** that automatically recommends whether a bus should **STOP**, **SKIP**, or **EARLY DEPART** at each stop — balancing passenger demand against bus capacity in real time.

---

## ✨ Features

### 👤 Passenger App
- **Login & Sign Up** — Secure Firebase Authentication
- **Home Dashboard** — Live trip status, balance display, quick actions
- **Live Bus Occupancy** — Real-time progress bar showing how full your bus is (Green / Orange / Red)
- **QR Check-In** — Scan a QR code at a bus stop to register your boarding intent
- **Routes Browser** — Browse all active bus routes with stop lists and an interactive map
- **Notifications** — Receive real-time alerts when your bus is skipping your stop or departing early
- **Digital Wallet** — View balance and top-up history
- **Profile** — View and edit personal info, change password

### 🚍 Driver Dashboard
- View assigned active trip and route
- See real-time passenger check-ins at upcoming stops
- **Decision Engine** — Automatically calculates STOP / SKIP / EARLY DEPART per stop:
  - `SKIP` — No passengers waiting, or bus is full
  - `STOP` — Passengers waiting and space available
  - `EARLY DEPART` — High demand at stop with available seats
- Send alerts to waiting passengers when skipping or departing early
- End trip when route is complete

### 🛠️ Admin Dashboard
- **Manage Users** — Create Passenger/Driver accounts, change roles
- **Manage Stops** — Add/edit/delete bus stops with GPS coordinates and max threshold settings
- **Manage Routes** — Build routes from stops, activate/deactivate routes
- **Manage Trips** — Assign drivers and buses to routes, start and end trips
- **Fleet Dashboard** — View all active buses and their real-time occupancy
- **System Reports** — Analytics on trips, check-ins, stop decisions, and occupancy records

---

## 🧠 Decision Engine Logic

The core algorithmic feature of SDBS. Priority order (first matching rule wins):

| Rule | Condition | Action |
|------|-----------|--------|
| 1 | No passengers waiting at stop | **SKIP** — Save time |
| 2 | Bus is at full capacity | **SKIP** — Cannot board anyone |
| 3 | Waiting passengers > available seats | **STOP** — Board as many as possible, warn others |
| 4 | Waiting >= stop's max threshold AND space available | **EARLY DEPART** — Rush to serve high demand |
| 5 | Default | **STOP** — Normal stop |

All decisions are **logged to Firestore** for audit and analytics, and **notifications** are automatically sent to affected passengers.

---

## 🗃️ Firestore Data Model

| Collection | Description |
|---|---|
| `users` | User profiles with role (`Passenger`, `Driver`, `Admin`) and wallet balance |
| `users/{uid}/transactions` | Immutable wallet top-up history |
| `stops` | Bus stops with GPS coordinates and crowd thresholds |
| `routes` | Routes with ordered list of stop IDs, active/inactive flag |
| `buses` | Bus fleet with current occupancy and capacity |
| `trips` | Active/completed trips linking bus, driver, and route |
| `checkIns` | Passenger boarding intents at specific stops |
| `stopDecisions` | Audit log of all STOP/SKIP/EARLY DEPART decisions |
| `notifications` | Real-time passenger alerts |
| `occupancyRecords` | Historical occupancy data for analytics |

---

## 🔐 Security

Firestore Security Rules enforce role-based access:
- **Passengers** can only read/write their own data (profile, check-ins, notifications)
- **Drivers** can update their assigned trip and send notifications
- **Admins** have full read/write access to all collections
- Self-signup is always `Passenger` — roles can only be changed by Admins
- Wallet balance cannot be modified directly by users (prevents fraud)
- All transactions are **immutable** once written

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile/Web Framework | [Flutter](https://flutter.dev/) |
| Backend & Auth | [Firebase](https://firebase.google.com/) (Auth + Firestore) |
| State Management | [Provider](https://pub.dev/packages/provider) |
| Maps | [flutter_map](https://pub.dev/packages/flutter_map) + [latlong2](https://pub.dev/packages/latlong2) |
| QR Code | [qr_flutter](https://pub.dev/packages/qr_flutter) + [mobile_scanner](https://pub.dev/packages/mobile_scanner) |
| Form Validation | [form_validator](https://pub.dev/packages/form_validator) |

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (^3.9.2)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- A Firebase project with **Authentication** and **Firestore** enabled

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/ALDANI-MO/sdbs.git
   cd sdbs
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Email/Password Authentication
   - Enable Cloud Firestore
   - Run `flutterfire configure` and replace `lib/firebase_options.dart` with your config

4. **Deploy Firestore Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

---

## 📁 Project Structure

```
lib/
├── main.dart                  # App entry point, Firebase init, Provider setup
├── firebase_options.dart      # Firebase configuration (auto-generated)
├── auth/
│   ├── login.dart             # Login screen
│   └── signup.dart            # Passenger registration screen
├── home/
│   ├── home.dart              # Passenger home dashboard
│   ├── cards.dart             # Wallet & transaction history
│   └── profile.dart           # User profile screen
├── options/
│   ├── check_in.dart          # QR check-in flow
│   ├── qr_scanner_page.dart   # Camera QR scanner
│   ├── stop_trip_picker.dart  # Stop/trip selection after scan
│   ├── routes_page.dart       # Browse routes & stops with map
│   └── notifications.dart     # Passenger notifications
├── driver/
│   └── driver_dashboard.dart  # Driver trip management + decision engine UI
├── admin/
│   ├── admin_dashboard.dart   # Admin home
│   ├── manage_users.dart      # User CRUD
│   ├── manage_stops.dart      # Stop CRUD with map
│   ├── manage_routes.dart     # Route builder
│   ├── manage_trips.dart      # Trip management
│   ├── fleet_dashboard.dart   # Real-time fleet overview
│   └── system_reports.dart    # Analytics & reports
├── services/
│   ├── auth_service.dart      # Firebase Auth operations
│   ├── transit_service.dart   # All Firestore transit operations
│   ├── wallet_service.dart    # Wallet/balance operations
│   └── decision_service.dart  # Decision engine + audit logging
├── providers/
│   └── user_provider.dart     # Global user state
├── theme/
│   └── app_theme.dart         # App-wide colors, styles, input decorations
└── utils/
    └── error_handler.dart     # Centralized error display helpers
```

---

## 👤 Author

**Mohammad Al-Dani** — [@ALDANI-MO](https://github.com/ALDANI-MO)

---

## 📄 License

This project is for educational/portfolio purposes.
