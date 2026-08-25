# Aqua Link PH — Setup Guide (one-time, ~15 minutes)

Follow these steps in order. After step 5 the app runs; steps 6-8 prepare it for the defense and deployment.

---

## 1 · Create the Firebase project

1. Go to <https://console.firebase.google.com> and click **Add project**.
2. Name: `aqua-link-ph` (any unique name works). Analytics: optional.
3. Open **Build → Authentication → Get started → Email/Password → Enable → Save**.

## 2 · Create the Firestore database

1. **Build → Firestore Database → Create database**.
2. Choose **Production mode** (the repo's `firestore.rules` will protect it), nearest region, Enable.

## 3 · Register a Web app

1. Project Overview → the **`</>`** (Web) icon.
2. Nickname: `Aqua Link PH Web` → Register app. You do **not** need to copy the config manually — the next step generates it.

## 4 · Connect the CLI (already installed on this machine)

```powershell
dart pub global activate flutterfire_cli
```

Make sure `pub\bin` is on your PATH (usually `%LOCALAPPDATA%\Pub\Cache\bin`).

## 5 · Generate `lib/firebase_options.dart`

From the project folder:

```powershell
cd "C:\Users\iceic\OneDrive\Documents\Default Project\aqua_link_ph"
flutterfire configure
```

- Select your new Firebase project.
- Keep only **web** selected.
- This overwrites `lib/firebase_options.dart` with real credentials.

Run the app:

```powershell
flutter run -d chrome
```

The setup screen disappears and you land on the login page. ✅

## 6 · Publish security rules

```powershell
firebase login                 # opens browser once
firebase use --add             # pick your project, alias: default
firebase deploy --only firestore:rules
```

## 7 · First admin account

1. In the running app choose **Register as customer** and register YOUR email.
2. When prompted *"First account detected — become admin?"* click **Become admin**.
   (This one-time elevation is guarded by a bootstrap flag in Firestore.)
3. Sign out, sign back in — you now land on `/admin`.

## 8 · Defense data

Admin portal → **Settings → Generate demo data**, then create the accounts it lists
(sign in once with each to verify):

| Account | Role | Password |
|---|---|---|
| `staff@aquaph.test` | Staff | `Aqua123!` |
| `maria@aquaph.test` | Customer | `Aqua123!` |

## 9 · Deploy (optional but impressive at the defense)

```powershell
flutter build web --release
firebase deploy --only hosting,firestore:rules
```

Your system is live at `https://<project-id>.web.app`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Setup screen keeps showing | `flutterfire configure` wasn't run or failed — rerun it from the project root |
| `Email/Password sign-in disabled` popup | Enable it under Authentication → Sign-in method |
| `permission-denied` errors | Deploy rules (step 6); make sure your user doc has the right `role` |
| Camera black in scanner | Browsers require HTTPS or localhost; over LAN IP use Chrome flags or the manual code entry box |
| QR scan finds nothing | Codes are exact strings like `GLN-0001`; check Gallons & QR module |
