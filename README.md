# Aqua Link PH

**A Web-Based Water Station Management System with QR-Based Gallon Inventory, Delivery Tracking, and Profit Analytics for Edelycalie Water Refilling Station**

Bachelor of Science in Information Technology — Capstone Project

Built with **Flutter Web (Dart)** + **Firebase** (Authentication · Cloud Firestore · Hosting), **qr_flutter**, **mobile_scanner**, and **fl_chart**.

---

## Features

| Portal | Modules |
|---|---|
| **Admin** (`/admin`) | Business dashboard, order monitoring, customer records, gallon registration & QR printing, inventory with reorder alerts, sales monitoring with walk-in POS entry, expense tracking, profit analytics reports (daily/weekly/monthly), staff account management |
| **Staff** (`/staff`) | Today's operations board, order processing queue, delivery coordination sheets, **camera QR gallon scanning** (+ manual code fallback), payment verification |
| **Customer** (`/customer`) | Product & price list, online ordering, real-time order tracking with progress stepper, near-arrival notification, personal gallon visibility |

### QR gallon lifecycle
`Available → Assigned → Out for Delivery → With Customer → Returned` (+ Damaged / Lost)
Every transition is validated and written to a per-gallon **history subcollection** in Firestore.

### Real-time
All lists and dashboards use Firestore `snapshots()` streams (StreamBuilder) — orders, statuses, gallons, inventory and sales update live across all connected users. No polling.

---

## Quick start

```bash
flutter pub get
flutter run -d chrome        # development
flutter build web --release  # production bundle in build/web
```

> The app requires a Firebase project. See **SETUP_GUIDE.md** for the one-time
> configuration (the app shows an interactive setup checklist until Firebase is connected).

## Deployment (Firebase Hosting)

```bash
firebase login
firebase use --add                # select your project once
flutter build web --release
firebase deploy --only hosting,firestore:rules
```

## Demo data for the defense

Sign in as Admin → **Settings → Generate demo data**.
Creates products, customers, ~90 orders & sales over 35 days, 30 QR gallons in every state, and expenses — so charts and dashboards are presentation-ready instantly.

Demo accounts created by the seeder (password `Aqua123!`):
- `staff@aquaph.test` — Staff portal
- `maria@aquaph.test` — Customer portal

## Project structure

```
lib/
├── main.dart                  # bootstrap + provider wiring
├── firebase_options.dart      # flutterfire-generated config (template until configured)
├── core/
│   ├── constants/             # AppColors · AppConstants · roles/statuses/collections
│   ├── theme/                 # AppTheme · AppTextStyles
│   └── utils/                 # formatters (₱ PHP) · validators
├── models/                    # User · Customer · Order · Gallon(+History) · InventoryItem · Sale · Expense · Notification
├── services/                  # auth · customer · order · gallon · inventory · sales · expense · notification · seed
├── providers/                 # AuthProvider (auth state + live role profile)
├── routes/app_router.dart     # role-guarded routing: /admin /staff /customer
├── screens/
│   ├── auth/                  # splash · login · register (+ first-admin bootstrap)
│   ├── admin/                 # 10 modules incl. Reports & Settings
│   ├── staff/                 # operations modules + scanner
│   ├── customer/              # ordering & tracking
│   ├── shared/                # order details dialog (staff/admin)
│   └── error/                 # access denied · firebase setup guide
└── widgets/                   # PortalShell responsive sidebar/drawer · charts · common widgets

firestore.rules                # role-based server-side security
firebase.json                  # Hosting config (build/web + SPA rewrites)
```

## Security model

Firestore Security Rules enforce RBAC **server-side**:
- customers read/write only their own records; can only cancel their own pending orders
- expenses are admin-only; sales readable by staff but immutable/deletable only by admin
- gallons & history writable only by admin/staff; customers see gallons linked to them
- first-account admin elevation guarded by `/config/bootstrap` flag

See `firestore.rules`.
