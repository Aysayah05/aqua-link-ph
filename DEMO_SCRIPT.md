# Capstone Defense — Demo Script (12–15 min)

Run `flutter run -d chrome` (or open the deployed URL) **before** the panel arrives.
Log in as admin and keep the tab ready. Suggested browser zoom ~90%.

> Tip: open a second browser window (or use your phone) logged in as the customer
> `maria@aquaph.test` so real-time sync is visible side-by-side.

---

## 1 · The problem & the solution (2 min)

- Manual sales records, untracked gallons, scattered delivery messages, no profit visibility.
- Aqua Link PH centralizes customers, orders, QR-tracked gallons, deliveries, payments, expenses and analytics into one responsive web system.

## 2 · Authentication & role-based routing (2 min)

- Show login screen. Sign in as **admin**.
- Point out: Firebase Authentication handles credentials; Firestore stores the profile with a `role`; the router sends each role to its own portal (`/admin`, `/staff`, `/customer`).
- Mention: security is enforced by **Firestore rules**, not hidden buttons — try opening `/staff` while logged in as admin → Access Denied screen proves guards work both ways.

## 3 · Admin dashboard & profit analytics (3 min)

- Today's Sales, active orders, gallons with customers, low-stock alert cards — all live streams.
- Daily sales bar chart (14 days), expense pie chart, Revenue vs Expenses line (6 months).
- Open **Reports**: daily/weekly/monthly summaries; explain **Profit = Revenue − Expenses** computed from recorded data only.

## 4 · Orders → QR gallons → delivery (4 min) ★ core feature

1. Admin → **Orders**: open the pending order for *Juan Dela Cruz* → **Confirm** → **Assign gallons** (auto-picks available containers).
2. Gallons & QR module: show registered gallons `GLN-####`, click one to show its QR + history timeline. Register new gallons live to show sequential QR generation + printable label sheet.
3. Switch to staff window: log in `staff@aquaph.test`.
   - **Orders** queue shows the confirmed order in real time → Start preparing → Out for delivery.
   - **Scan Gallon**: scan/print any QR or type the code manually (desktop-friendly fallback). Show the gallon's status transitions being validated (try an illegal move to show the error toast).
   - **Deliveries** board: full address/contact/quantity card → click **Notify near arrival**.
4. Customer window (maria@aquaph.test): near-arrival banner appears instantly; order stepper advanced; My Gallons lists her containers ("awaiting return").
5. Back to staff → mark **Delivered**, collect payment (cash/GCash) → sale record created automatically.

## 5 · Transactions & inventory integrity (1.5 min)

- Staff → **Transactions**: verify an unpaid delivered order → confirm it disappears from the queue and appears under Admin → Sales.
- Admin → **Inventory**: walk-in sale decremented stock; low-stock reorder alert highlighted.

## 6 · Customer self-service recap (1 min)

- Register flow, product/price list from Firestore, order form with live total, confirmation with order ID, tracking stepper, gallon visibility.

## 7 · Wrap-up (30 s)

- Responsive: resize the window — sidebar collapses to drawer, tables become cards.
- Deployment: `firebase deploy --only hosting` → live URL.
- Future work: push notifications, route optimization, GCash API integration.

---

### Likely panel questions

| Question | Answer |
|---|---|
| How is the QR secure? | The QR carries only the gallon ID (`GLN-0001`). All data lives in Firestore behind security rules; scanning resolves the record server-side. |
| What if two staff update the same gallon? | Status transitions are validated against the current Firestore state; invalid moves are rejected with feedback. |
| Why Flutter Web? | One Dart codebase, Material design, compiles to fast SPAs, deploys free on Firebase Hosting — fits the capstone stack requirement. |
| How is profit computed? | Sum of `sales` documents minus sum of `expenses` within the selected period — no hardcoded numbers. |
| Where is access control enforced? | Both UI route guards AND Firestore Security Rules (`firestore.rules`) server-side. |
