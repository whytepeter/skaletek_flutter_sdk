
# 🛠️ Fix iOS Plugin Registration Class Mismatch

## Overview

This patch resolves a **critical iOS build failure** in the `face_liveness_detector` Flutter plugin caused by a mismatch between the plugin registration class name used by Flutter and the one defined in Swift.

---

## ❗ Problem

When running `flutter run` on iOS (device or simulator), the following error is thrown:

```

Semantic Issue (Xcode): Unknown receiver 'FaceLivenessDetectorPlugin'; did you mean 'FaceLivenessPlugin'?
GeneratedPluginRegistrant.m:54:3

````

### Cause

Flutter expects an iOS plugin entry point named `FaceLivenessDetectorPlugin`, as inferred from the plugin name. However, the plugin implementation defines the main Swift class as:

```swift
public class FaceLivenessPlugin: NSObject, FlutterPlugin
````

This leads to an undefined symbol when Flutter’s `GeneratedPluginRegistrant.m` tries to register the plugin using the expected class name.

---

## ✅ Solution

This PR:

* Renames the Swift plugin file:

  ```
  FaceLivenessPlugin.swift → FaceLivenessDetectorPlugin.swift
  ```
* Updates the class declaration to match what Flutter expects:

  ```swift
  public class FaceLivenessDetectorPlugin: NSObject, FlutterPlugin
  ```
* Updates all internal references to use the new class name:

  ```swift
  let instance = FaceLivenessDetectorPlugin()
  ```

With these changes, Flutter can correctly register the iOS plugin and the application builds successfully.

---

## 🔍 Files Changed

| File                       | Change                                    |
| -------------------------- | ----------------------------------------- |
| `FaceLivenessPlugin.swift` | ✅ Renamed                                 |
| Class name                 | ✅ Renamed to `FaceLivenessDetectorPlugin` |
| Class reference            | ✅ Updated to match new name               |

---

## 🔧 How to Test

1. Pull this branch
2. Run:

   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter run
   ```
3. ✅ The app should build and launch without errors on iOS

---

## 📦 Compatibility

| Platform | Status       |
| -------- | ------------ |
| iOS      | ✅ Fixed      |
| Android  | ✅ Unaffected |
| macOS    | ❓ Not tested |

---

## 🙏 Additional Notes

This fix ensures that the plugin works out-of-the-box for iOS consumers using the standard Flutter plugin registration pipeline.

Maintainers are encouraged to review for:

* Naming consistency
* Registration flow
* Compatibility with Swift Package Manager structure

---

**Author**: \[@your-github-username]
**Date**: 2025-07-10

```

Let me know if you'd like this turned into a `PR_DESCRIPTION.md`, `CHANGELOG.md`, or GitHub issue template.
```
