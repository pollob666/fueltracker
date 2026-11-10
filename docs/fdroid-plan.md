# F-Droid Inclusion & FOSS Flavor Architectural Plan

> **LEGAL NOTICE & DISCLAIMER:**  
> All legal assessments, GPLv3 compatibility statements, and licensing interpretations contained within this document represent technical code and dependency audits and **[needs human/legal verification]** by a qualified intellectual property attorney or the copyright holder.

---

## 1. Executive Summary & Problem Statement

**Fuel Tracker** is licensed under the **GNU General Public License v3.0 (GPLv3)**. The application currently targets the Google Play Store and GitHub Releases using a single unified APK build. 

However, a comprehensive dependency audit of `pubspec.lock` and native Gradle configurations reveals multiple dependencies that bundle proprietary, closed-source binary SDKs (Google Mobile Ads, Google Play Billing Client, Google ML Kit on-device vision models, and Google Play Services Location).

Under the official **F-Droid Inclusion Policy** and standard software freedom guidelines:
1. **Proprietary Binary Incompatibility:** F-Droid builds apps strictly from source in an isolated environment without network access during compilation and without proprietary Google Play Services or binary blobs.
2. **GPLv3 License Compatibility Risk:** Distributing a GPLv3-licensed binary linked against proprietary, closed-source third-party libraries (without an explicit GPL linking exception from all copyright holders) presents copyright and compliance violations **[needs human/legal verification]**.
3. **Anti-Feature Flags:** F-Droid will either reject the application or tag it with multiple user-facing Anti-Features (`Ads`, `Tracking`, `NonFreeDep`, `NonFreeAssets`), significantly harming discoverability.

To resolve these barriers while maintaining monetization and Play Store capabilities, this document specifies a **Dual-Flavor Strategy** (`foss` vs `play`) to cleanly decouple all proprietary dependencies from the open-source codebase.

---

## 2. Proprietary & Closed-Source Dependency Audit

The following table lists every dependency identified in `pubspec.lock` and native Android build files that introduces proprietary binaries, closed-source models, or non-free services:

| Package | Wrapper License | Native Binary Artifact & License | GPLv3-Compatible? * | F-Droid Anti-Feature | Rationale & Impact |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **`google_mobile_ads`** (`^9.2.0`) | Apache-2.0 | `com.google.android.gms:play-services-ads:25.5.0`<br>`com.google.android.ump:user-messaging-platform:4.0.0`<br>*(Google Proprietary Terms of Service)* | **No**<br>*[needs human/legal verification]* | `Ads`<br>`Tracking`<br>`NonFreeDep` | Serves Google AdMob banner and interstitial video ads. Tracks user telemetry and advertising IDs. Completely unacceptable for F-Droid main repository. |
| **`google_mlkit_text_recognition`** (`^1.0.0`) | Apache-2.0 | `com.google.mlkit:text-recognition:16.0.1`<br>*(Google ML Kit Terms of Service, closed-source C++ binary & proprietary model weights)* | **No**<br>*[needs human/legal verification]* | `NonFreeDep`<br>`NonFreeAssets` | Provides on-device optical character recognition for dispenser receipts and odometers. Bundles closed-source neural network weights and native binaries. |
| **`google_mlkit_commons`** (`^1.0.0`) | Apache-2.0 | `com.google.mlkit:common:18.10.0`<br>*(Google ML Kit Proprietary Terms)* | **No**<br>*[needs human/legal verification]* | `NonFreeDep` | Transitive base library required by `google_mlkit_text_recognition`. Dynamically links Google proprietary runtime code. |
| **`in_app_purchase_android`** (`^0.5.5`) (via `in_app_purchase`) | BSD-3-Clause | `com.android.billingclient:billing:9.1.0`<br>*(Google Play Billing API Terms of Service, closed-source)* | **No**<br>*[needs human/legal verification]* | `NonFreeDep` | Implements Google Play Billing Client for ad-removal purchases. Enforces dependency on proprietary Google Play Store client and services. |
| **`geolocator_android`** (`^4.6.2`) (via `geolocator`) | MIT | `com.google.android.gms:play-services-location:21.2.0`<br>*(Google Play Services Proprietary SDK)* | **Ambiguous**<br>*[needs human/legal verification]* | `NonFreeDep` | Bundles Play Services Location client. Although the Dart wrapper falls back to Android AOSP `LocationManager` when Play Services are missing, the native proprietary `.aar` is statically bundled in the APK unless excluded at build time. |
| **`webview_flutter`** (`^4.13.0`) | BSD-3-Clause | Transitive dependency of `google_mobile_ads`. Native Android System WebView (AOSP / Chromium). | **Yes**<br>*[needs human/legal verification]* | None (by itself) | Wrapper is FOSS, but its present inclusion in the dependency graph is solely driven by Google Mobile Ads ad-rendering containers. |

*\* Note: GPLv3 Section 6 requires conveying Corresponding Source for all linked components. Proprietary Google SDKs cannot be distributed under GPLv3 without an explicit Free Software linking exception granted by the copyright holders [needs human/legal verification].*

---

## 3. Product Flavor Strategy: `foss` vs `play`

To achieve 100% compliance with F-Droid and GPLv3 without losing Google Play features, the project must introduce two discrete product flavors:

```
                      +-----------------------------+
                      |    FuelTracker Core         |
                      |  (Pure Dart & Local SQLite) |
                      +--------------+--------------+
                                     |
             +-----------------------+-----------------------+
             |                                               |
+------------v------------+                     +------------v------------+
|     Flavor: `play`      |                     |     Flavor: `foss`      |
| (Google Play & Direct)  |                     | (F-Droid & FOSS Stores) |
+-------------------------+                     +-------------------------+
| • Google Mobile Ads SDK |                     | • Zero Ads (No AdMob)   |
| • Play Billing (IAP)    |                     | • 100% Free / No IAP    |
| • Google ML Kit OCR     |                     | • FOSS OCR / Manual     |
| • FusedLocationProvider |                     | • Android LocationMgr   |
| • Anti-Features: YES    |                     | • Anti-Features: NONE   |
+-------------------------+                     +-------------------------+
```

### 3.1 Android Gradle Configuration (`android/app/build.gradle`)

Define flavor dimensions to isolate Android dependencies and manifest metadata:

```groovy
android {
    ...
    flavorDimensions = ["distribution"]

    productFlavors {
        foss {
            dimension "distribution"
            // Clean application ID for FOSS build
            applicationId "com.pollob666.fueltracker"
        }
        play {
            dimension "distribution"
            applicationId "com.pollob666.fueltracker"
        }
    }
}
```

### 3.2 Manifest Separation

1. **Remove AdMob Application ID from base manifest:**  
   Remove `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" ... />` from `android/app/src/main/AndroidManifest.xml`.
2. **Move Play-Specific Metadata:**  
   Create `android/app/src/play/AndroidManifest.xml`:
   ```xml
   <manifest xmlns:android="http://schemas.android.com/apk/res/android">
       <application>
           <meta-data
               android:name="com.google.android.gms.ads.APPLICATION_ID"
               android:value="ca-app-pub-4519441960386265~5488026786"/>
       </application>
   </manifest>
   ```
   The `foss` flavor manifest remains completely free of proprietary advertising metadata.

---

## 4. Code Architecture & Dependency Inversion

Flutter imports all packages declared in `pubspec.yaml` into the compilation unit. To prevent `foss` builds from linking or compiling proprietary classes, we apply the **Dependency Inversion Principle (DIP)** with compile-time entry points.

### 4.1 Abstraction Interfaces (Core Module)

Define abstract contracts in `lib/services/interfaces/`:

```dart
// lib/services/interfaces/ad_service_interface.dart
abstract class IAdService {
  Future<void> initialize();
  bool get areAdsSuppressed;
  Widget buildBannerAdWidget();
  Future<void> showInterstitialAdIfEligible();
}

// lib/services/interfaces/purchase_service_interface.dart
abstract class IPurchaseService {
  Future<void> initialize();
  Stream<bool> get isAdRemovedStream;
  Future<void> buyNonConsumable();
  Future<void> restorePurchases();
}

// lib/services/interfaces/ocr_service_interface.dart
abstract class IOcrService {
  Future<OcrParsedResult> processImage(String imagePath);
}
```

### 4.2 Implementation Variants

#### A. Advertising (`IAdService`)
- **`PlayAdService`:** Implements `google_mobile_ads`, displays banners, loads interstitial video ads, and respects `isAdRemovedProvider`.
- **`FossAdService`:** A lightweight zero-overhead stub (`NoOp`). Permanently marks ads as suppressed, returns `SizedBox.shrink()` for banners, and performs no network requests.

#### B. Monetization & IAP (`IPurchaseService`)
- **`PlayPurchaseService`:** Implements `in_app_purchase` via Google Play Billing Client.
- **`FossPurchaseService`:** `NoOpPurchaseService`. In FOSS builds, all features are completely free by default. In the "Settings / About" screen, replace the "Remove Ads" IAP button with open donation channels (GitHub Sponsors, Liberapay, Ko-fi, or direct repository donation links) which F-Droid permits under open donation guidelines.

#### C. Optical Character Recognition (`IOcrService`)
- **`PlayOcrService`:** Retains `google_mlkit_text_recognition` for on-device machine learning OCR.
- **`FossOcrService`:**
  - *Option 1 (Zero-dependency):* Retains the pure Dart regex parser (`OcrVisionService.parseReceiptText`) with clipboard paste or manual entry.
  - *Option 2 (FOSS Native OCR):* Integrate an open-source OCR engine (e.g. Tesseract 5 via a clean FOSS C++ native asset or Android Tesseract wrapper).
  - *Option 3 (Graceful Fallback):* Conditionally hide the camera OCR buttons in refueling forms if no FOSS OCR provider is configured.

### 4.3 Compile-Time Entry Point Separation

Configure discrete main entry points for builds:

```
lib/
├── main_foss.dart          # Initializes FossAdService, FossPurchaseService, FossOcrService
├── main_play.dart          # Initializes PlayAdService, PlayPurchaseService, PlayOcrService
└── app.dart                # Shared app root taking service configuration
```

- **Build FOSS APK:**
  ```bash
  flutter build apk --flavor foss -t lib/main_foss.dart
  ```
- **Build Google Play APK / App Bundle:**
  ```bash
  flutter build appbundle --flavor play -t lib/main_play.dart
  ```

---

## 5. F-Droid Build Recipe (`.fdroid.yml`) Specification

When ready for submission to the F-Droid metadata repository, the build recipe will be structured as follows:

```yaml
Categories:
  - Navigation
  - Utilities
License: GPL-3.0-or-later
AuthorName: Andalib Bin Haque
AuthorEmail: pollob666@gmail.com
SourceCode: https://github.com/pollob666/fueltracker
IssueTracker: https://github.com/pollob666/fueltracker/issues
Changelog: https://github.com/pollob666/fueltracker/releases

AutoUpdateMode: Version
UpdateCheckMode: Tags

Builds:
  - versionName: 3.8.0
    versionCode: 4
    commit: v3.8.0
    target: lib/main_foss.dart
    output: build/app/outputs/flutter-apk/app-foss-release.apk
    gradle:
      - fossRelease
    scandelete:
      - android/app/src/play
```

---

## 6. Implementation Roadmap

| Milestone | Phase | Scope of Work | Deliverables |
| :--- | :--- | :--- | :--- |
| **Phase 1** | **Interface Inversion** | Abstract `AdService`, `InAppPurchaseService`, and `OcrVisionService` behind clean interfaces. | `lib/services/interfaces/*.dart` |
| **Phase 2** | **FOSS Stubs & Providers** | Create `FossAdService` (No-Op), `FossPurchaseService` (Free-tier), and graceful OCR fallback. | `lib/services/foss/*.dart` |
| **Phase 3** | **Gradle Flavors** | Add `flavorDimensions` (`foss`, `play`) to `build.gradle` and split `AndroidManifest.xml` AdMob metadata. | `android/app/build.gradle`<br>`android/app/src/play/AndroidManifest.xml` |
| **Phase 4** | **Entrypoints & Verification** | Add `main_foss.dart` and `main_play.dart`. Run independent test suites and verify zero proprietary symbols in `fossRelease` APK. | CI workflow matrix updating `ci.yml` |
| **Phase 5** | **F-Droid Submission** | Submit metadata merge request to `fdroiddata` with complete reproducible build recipe. | F-Droid RFP / MR |

---

## 7. Legal & Licensing Summary

> **ATTENTION:**  
> 1. In the current unified build, distributing binaries that link Google Mobile Ads, ML Kit, and Play Billing with GPLv3 code without an explicit linking exception violates GPLv3 licensing terms **[needs human/legal verification]**.
> 2. Introducing the `foss` flavor with 100% Free and Open Source software ensures compliance with GPLv3 and allows unencumbered distribution across F-Droid, Debian, and Linux platforms **[needs human/legal verification]**.
> 3. For the `play` flavor, the repository copyright holder should consider adding an explicit **GPLv3 Classpath/Linking Exception** (e.g. permitting linking with Google Play Services and Google Play Billing APIs) to ensure complete legal compliance for Play Store releases **[needs human/legal verification]**.
