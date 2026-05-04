# FarmerChat — App Store Submission Guide

> **iOS Note:** Android uses `.apk` files. iOS uses `.ipa` files (iOS App Archive).  
> This guide covers the full iOS lifecycle: dev setup → production build → App Store upload → post-submission changes.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [App Store Connect Setup](#2-app-store-connect-setup)
3. [Xcode Project Configuration for Production](#3-xcode-project-configuration-for-production)
4. [Building a Production IPA](#4-building-a-production-ipa)
5. [Uploading to App Store Connect](#5-uploading-to-app-store-connect)
6. [App Store Listing & Metadata](#6-app-store-listing--metadata)
7. [Submitting for Apple Review](#7-submitting-for-apple-review)
8. [After Approval — Releasing to Users](#8-after-approval--releasing-to-users)
9. [Updating the App (New Versions)](#9-updating-the-app-new-versions)
10. [Switching to a Production Backend / Changing Environments](#10-switching-to-a-production-backend--changing-environments)
11. [Troubleshooting Common Errors](#11-troubleshooting-common-errors)
12. [Quick Reference: Key Identifiers](#12-quick-reference-key-identifiers)

---

## 1. Prerequisites

### Apple Developer Account
- You need an **Apple Developer Program** membership ($99/year).
- Enroll at: https://developer.apple.com/programs/
- The account email becomes your App Store Connect login.
- Your existing team ID is: `49VAPTB77A`

### Tools Required
| Tool | Version | Purpose |
|------|---------|---------|
| Xcode | 15+ | Build, archive, upload |
| macOS | Ventura (13)+ | Required for Xcode 15 |
| Transporter (App) | Latest | Alternate upload method |

Install Transporter from the Mac App Store (free, by Apple) as a backup uploader.

### Certificates & Provisioning Profiles
Your project uses **Automatic Code Signing** (`CODE_SIGN_STYLE = Automatic`).  
Xcode manages certificates automatically when you are signed in with your Apple ID.

To verify:
1. Open `FarmerChat.xcodeproj` in Xcode
2. Click the **FarmerChat** project in the navigator
3. Select the **FarmerChat** target → **Signing & Capabilities**
4. Ensure **Automatically manage signing** is checked
5. Set **Team** to `Digital Green` (Team ID: `49VAPTB77A`)

---

## 2. App Store Connect Setup

### 2.1 Create the App Record

1. Go to https://appstoreconnect.apple.com
2. Sign in with your Apple Developer account
3. Click **Apps** → **"+"** (top left) → **New App**
4. Fill in:

| Field | Value |
|-------|-------|
| Platform | iOS |
| Name | FarmerChat (or your desired display name) |
| Primary Language | English (or target language) |
| Bundle ID | `org.digitalgreen.farmer.chatbot` |
| SKU | A unique internal identifier, e.g. `farmerchat-ios-2026` |
| User Access | Full Access |

> **Bundle ID must exactly match** what is in your Xcode project.  
> Your current Bundle ID: `org.digitalgreen.farmer.chatbot`

### 2.2 Register the Bundle ID (if not already done)

1. Go to https://developer.apple.com/account/resources/identifiers
2. Click **"+"** → **App IDs** → **App**
3. Enter description: `FarmerChat`
4. Select **Explicit** and enter: `org.digitalgreen.farmer.chatbot`
5. Enable any **Capabilities** your app uses (Push Notifications, etc.)
6. Click **Register**

---

## 3. Xcode Project Configuration for Production

### 3.1 Set Version Numbers

In Xcode:
- Select project → **FarmerChat** target → **General** tab
- **Version** (Marketing Version): e.g. `1.0.0` — shown to users on App Store
- **Build** (Current Project Version): e.g. `1` — must increment with every upload

Or edit `FarmerChat.xcodeproj/project.pbxproj` directly:
```
MARKETING_VERSION = 1.0;         ← User-facing (e.g. 1.0, 1.1, 2.0)
CURRENT_PROJECT_VERSION = 1;     ← Build number — MUST be unique per upload
```

> **Rule:** You can reuse a Marketing Version, but the Build number must be strictly  
> higher than any previously uploaded build. Apple rejects duplicates.

### 3.2 Set the Correct Scheme and Configuration

Make sure you are building the **Release** configuration (not Debug):

1. In Xcode, click the scheme selector (top center bar)
2. Click **Edit Scheme…**
3. Select **Archive** in the left panel
4. Set **Build Configuration** to **Release**

### 3.3 Verify Entitlements

Your app has a custom entitlements file at `FarmerChat/FarmerChat.entitlements`.  
Open it and confirm only the capabilities you actually use are listed.  
Unused entitlements cause App Review rejections.

### 3.4 Check Info.plist / Privacy Strings

Apple requires a **usage description string** for every privacy-sensitive API.  
Common ones to verify in `Info.plist`:

| Key | Required If |
|-----|-------------|
| `NSCameraUsageDescription` | App accesses camera |
| `NSMicrophoneUsageDescription` | App records audio |
| `NSLocationWhenInUseUsageDescription` | App uses location |
| `NSPhotoLibraryUsageDescription` | App reads photos |

Missing strings = **automatic rejection** by Apple.

---

## 4. Building a Production IPA

An IPA is the iOS equivalent of an Android APK. Here is how to create one:

### Step 1 — Select the Right Device Target

In Xcode, set the build destination to **Any iOS Device (arm64)**, NOT a simulator.  
Simulator builds cannot be submitted to Apple.

```
Scheme Selector → [FarmerChat] → [Any iOS Device (arm64)]
```

### Step 2 — Archive the App

```
Xcode Menu → Product → Archive
```

This compiles a Release build and adds it to the **Organizer** window.  
Wait for the spinner to finish (typically 1–5 minutes).

### Step 3 — Open the Organizer

```
Xcode Menu → Window → Organizer
```

You will see your new archive listed with today's date and version number.

### Step 4 — Distribute the App

1. Select your archive in Organizer
2. Click **Distribute App**
3. Choose **App Store Connect** → **Next**
4. Choose **Upload** → **Next**
5. Leave all checkboxes at their defaults (Strip Swift Symbols, Upload Symbols) → **Next**
6. Select **Automatically manage signing** → **Next**
7. Review the summary → Click **Upload**

Xcode uploads the IPA directly to App Store Connect.  
You will receive a confirmation when the upload succeeds.

### Alternative: Export IPA Manually

If you need the `.ipa` file on disk (e.g. for enterprise distribution or sharing):

1. In Organizer → Select Archive → **Distribute App**
2. Choose **App Store Connect** → **Export** (instead of Upload)
3. Choose a save location
4. The `.ipa` file will be saved to that folder

Then upload it later via **Transporter** (Mac App Store app by Apple):
1. Open Transporter
2. Sign in with your Apple ID
3. Drag and drop the `.ipa` file
4. Click **Deliver**

---

## 5. Uploading to App Store Connect

After upload (via Xcode or Transporter), Apple processes the build.  
This takes **10–30 minutes**.

### Verify the Build Appeared

1. Go to https://appstoreconnect.apple.com → Your App → **TestFlight** tab
2. The build should appear with status **"Processing"**
3. When status changes to **"Ready to Submit"**, it can be attached to a release

> If you see **"Missing Compliance"**, Apple is asking about export compliance  
> (encryption). Answer the questions about whether your app uses encryption.  
> Most apps answer: **No encryption** (or standard HTTPS only).

---

## 6. App Store Listing & Metadata

In App Store Connect → Your App → **App Store** tab → **1.0 Prepare for Submission**:

### Required Fields

| Field | Notes |
|-------|-------|
| **App Previews and Screenshots** | Required for iPhone 6.5" and 5.5" at minimum |
| **Promotional Text** | Up to 170 chars, can be updated without resubmission |
| **Description** | Full app description, up to 4000 chars |
| **Keywords** | Comma-separated, max 100 chars total |
| **Support URL** | Must be a live, reachable URL |
| **Marketing URL** | Optional |
| **Version** | What's new in this version |
| **Category** | Primary category (e.g. Agriculture, Productivity) |
| **Age Rating** | Complete the questionnaire |
| **Copyright** | e.g. `2026 Digital Green` |
| **Contact Information** | Name, email, phone for App Review team |

### Screenshots

Apple requires screenshots for specific device sizes.  
Minimum required:
- **6.5" iPhone** (iPhone 14 Plus / 15 Plus): 1290×2796 px
- **5.5" iPhone** (iPhone 8 Plus): 1242×2208 px

Optional but recommended:
- **6.7" iPhone** (iPhone 16 Pro Max): 1320×2868 px
- **iPad Pro 12.9"** (if your app supports iPad)

Capture screenshots in Xcode Simulator:
```
Simulator → File → Save Screenshot (Cmd+S)
```

---

## 7. Submitting for Apple Review

### 7.1 Attach the Build

1. App Store Connect → Your App → **App Store** → **1.0 Prepare for Submission**
2. Scroll to **Build** section → Click **"+"**
3. Select the uploaded build
4. Click **Done**

### 7.2 Fill in Review Information

Under **App Review Information**:

| Field | Notes |
|-------|-------|
| Sign-in Required | Yes/No — if Yes, provide demo credentials |
| Demo Account | Username + password Apple reviewer can use |
| Notes | Explain any non-obvious functionality |
| Attachment | Optional: video or document showing app usage |

> Providing demo credentials and clear notes significantly speeds up review.

### 7.3 Set Release Options

Under **Version Release**:
- **Manually release this version** — you control when it goes live after approval
- **Automatically release this version** — goes live immediately after approval
- **Scheduled automatic release** — goes live at a specific date/time

### 7.4 Submit

Click **Add for Review** → Review the submission checklist → **Submit to App Review**

**Typical Review Times:**
- First submission: 1–3 days
- Updates: 1–2 days
- Expedited review (urgent bug): Request at https://developer.apple.com/contact/app-store/

---

## 8. After Approval — Releasing to Users

If you chose **Manual Release**:
1. App Store Connect → Your App → **App Store**
2. Click **Release This Version**

If you chose **Automatic Release**: no action needed.

After release, the app appears on the App Store within a few hours (CDN propagation).

---

## 9. Updating the App (New Versions)

Every update follows the same flow:

### Step 1 — Bump Version Numbers

In Xcode → FarmerChat target → General:
- Increment **Build** number (e.g. `1` → `2`) — **always required**
- Increment **Version** if it's a user-facing change (e.g. `1.0` → `1.1`)

### Step 2 — Archive & Upload

Same as Section 4 — `Product → Archive → Distribute App → Upload`

### Step 3 — Create a New Version in App Store Connect

1. App Store Connect → Your App → **App Store**
2. Click **"+"** next to iOS App (left sidebar) → **New Version**
3. Enter the new version number (must match `MARKETING_VERSION` in Xcode)
4. Fill in **"What's New in This Version"**
5. Attach the new build
6. Submit for review

> You do NOT need to redo all metadata — only update what changed.

---

## 10. Switching to a Production Backend / Changing Environments

This is one of the most critical steps before an App Store submission.

### Identify All Environment-Specific Values

Search the codebase for hardcoded URLs, keys, or flags:

```bash
# Find all API URLs in the project
grep -r "http" FarmerChat/ --include="*.swift" | grep -v "//.*http"

# Find environment flags or debug toggles
grep -r "DEBUG\|isDebug\|isDev\|staging\|localhost" FarmerChat/ --include="*.swift"
```

### Approach A — Build Configuration Flags (Recommended)

Use Xcode's Debug/Release build configurations to switch environments automatically.

In `FarmerChat.xcodeproj`:
1. Select the project → **FarmerChat** target → **Build Settings**
2. Search for **"Swift Compiler - Custom Flags"**
3. Under **Active Compilation Conditions**:
   - **Debug**: add `DEBUG`
   - **Release**: leave empty (or add `RELEASE`)

In code:
```swift
struct AppConfig {
    static let apiBaseURL: String = {
        #if DEBUG
        return "https://staging-api.farmerchat.digitalgreen.org"
        #else
        return "https://api.farmerchat.digitalgreen.org"
        #endif
    }()
}
```

This automatically uses staging in debug builds and production in release/App Store builds.

### Approach B — Separate Scheme per Environment

1. In Xcode → Scheme selector → **Manage Schemes**
2. Duplicate the FarmerChat scheme
3. Name one `FarmerChat (Dev)` and one `FarmerChat (Prod)`
4. Edit each scheme → **Run** → set Build Configuration accordingly
5. Use environment-specific `.xcconfig` files or `Info.plist` keys per configuration

### What to Change for Production

| Item | Dev / Staging Value | Production Value |
|------|--------------------|--------------------|
| API Base URL | `staging-api.*` | `api.*` (prod endpoint) |
| API Keys / Tokens | Dev keys | Production keys |
| Analytics | Disabled or dev property | Production property |
| Logging | Verbose | Minimal / off |
| Feature Flags | Experimental ON | Stable features only |
| Firebase / Crashlytics | Dev project | Prod project |

### Verifying a Production Build Locally

Build and run with Release configuration before uploading:
```
Xcode Menu → Product → Build For → Profiling
```
This builds with Release settings but runs on your device.

---

## 11. Troubleshooting Common Errors

### "No accounts with App Store distribution" / Signing Error
- Sign in to Xcode with your Apple ID: Xcode → Settings → Accounts → Add Apple ID
- Ensure your account has the **App Manager** or **Admin** role in App Store Connect

### "Invalid Binary" / Upload Rejected by Apple
- Confirm you archived with **Any iOS Device (arm64)**, not a simulator
- Confirm Build number is higher than the last uploaded build
- Check that all referenced frameworks are embedded

### "Missing Compliance" After Upload
- Answer the encryption questions in App Store Connect
- For apps using only HTTPS: select **No, my app does not use encryption**
- Or add to `Info.plist`:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
This skips the compliance question automatically.

### "The bundle does not support the minimum OS version"
- In Xcode → FarmerChat target → General → **Minimum Deployments**
- Set to iOS 16.0 or higher (match what your code actually requires)

### Build Processing Stuck in App Store Connect
- Normal processing time is 10–30 min
- If stuck over 2 hours: delete the build and re-upload
- Check https://developer.apple.com/system-status/ for Apple outages

### App Rejected by Review Team
Apple provides a specific rejection reason. Common causes and fixes:

| Rejection Reason | Fix |
|-----------------|-----|
| Missing privacy usage descriptions | Add NSXxx keys to Info.plist |
| Crashes on reviewer's device | Test on multiple real devices, not just simulator |
| Guideline 4.0 — Design | App looks unfinished; improve UI/UX |
| Guideline 2.1 — App Completeness | Demo account not working; fix credentials |
| Sign-in required not disclosed | Fill in demo account in Review Information |

Reply to the rejection in App Store Connect Resolution Center with your fix explanation.

---

## 12. Quick Reference: Key Identifiers

These identifiers are specific to the FarmerChat app:

| Key | Value |
|-----|-------|
| Bundle Identifier | `org.digitalgreen.farmer.chatbot` |
| Development Team ID | `49VAPTB77A` |
| Current Marketing Version | `1.0` |
| Current Build Number | `1` |
| Code Signing Style | Automatic |
| Entitlements File | `FarmerChat/FarmerChat.entitlements` |

---

## Submission Checklist

Use this before every App Store submission:

- [ ] Build number incremented (higher than last upload)
- [ ] Version number updated if user-facing change
- [ ] Archive built with **Any iOS Device (arm64)** target
- [ ] Archive built with **Release** build configuration
- [ ] All API URLs point to **production** endpoints
- [ ] Debug logging / verbose output disabled
- [ ] All `Info.plist` privacy usage descriptions filled in
- [ ] Screenshots uploaded for required device sizes
- [ ] App description, keywords, and metadata updated
- [ ] Demo account credentials provided (if login required)
- [ ] Support URL is live and reachable
- [ ] Age rating questionnaire completed
- [ ] Encryption compliance answered (or `ITSAppUsesNonExemptEncryption = false`)
- [ ] Entitlements match only the capabilities actually used
- [ ] Tested on a real physical device (not just simulator)

---

*Generated for FarmerChat iOS App · Digital Green · 2026*
