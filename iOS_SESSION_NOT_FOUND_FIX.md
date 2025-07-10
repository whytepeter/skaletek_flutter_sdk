# iOS SessionNotFound Error Fix Guide

## Problem
You're getting a "sessionNotFound" error on iOS for the face liveness detector, but it works fine on Android.

## Root Causes & Solutions

### 1. ✅ Fixed: Missing Camera Permissions
**Problem**: iOS requires explicit camera usage descriptions in Info.plist
**Solution**: Added camera and photo library permissions to `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to capture documents and perform face liveness detection for identity verification.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select documents for identity verification.</string>
```

### 2. ✅ Fixed: AWS Configuration Mismatch
**Problem**: iOS and Android were using different AWS configuration formats
**Solution**: Updated iOS configuration files to match Android format

Files updated:
- `ios/amplifyconfiguration.json`
- `ios/awsconfiguration.json`

### 3. ✅ Added: Enhanced Error Handling & Debugging
**Problem**: Limited visibility into what's causing the sessionNotFound error
**Solution**: Added comprehensive debugging and error handling

#### Debug Features Added:
- Platform-specific logging
- Session creation debugging
- Enhanced error messages
- Debug button for testing session creation

## Testing Steps

### 1. Clean and Rebuild
```bash
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# For iOS, also clean pods
cd ios
pod deintegrate
pod install
cd ..

# Run on iOS
flutter run -d "iPhone 15 Pro"
```

### 2. Check Debug Output
When you run the app, look for these debug messages in the console:

```
🔍 KYCFaceVerification Platform Info:
   Platform: ios
   Platform version: 17.0
   Is iOS: true
   Is Android: false

🚀 Starting liveness check...
   Platform: ios

🔍 KYCFaceLivenessDetector Debug Info:
   Session ID: abc123def4...
   Region: us-east-1
   Session ID length: 32
   Session ID is empty: false
```

### 3. Use Debug Button
In debug mode, you'll see a "Debug: Test Session Creation" button. Click it to test:
- Session token availability
- Session creation process
- Any errors in the process

## Common Issues & Solutions

### Issue 1: Still getting sessionNotFound
**Check**: 
1. Are you running on a real iOS device or simulator?
2. Does the simulator have camera access?
3. Are the AWS configuration files properly added to the Xcode project?

**Solution**: 
- Test on a real iOS device (simulators may have limited camera functionality)
- Ensure AWS configuration files are added to Xcode project target

### Issue 2: Camera permission denied
**Check**: 
1. Did the app request camera permission?
2. Was permission granted?

**Solution**: 
- Go to iOS Settings > Privacy & Security > Camera
- Enable camera access for your app
- Restart the app

### Issue 3: AWS configuration not found
**Check**: 
1. Are the configuration files in the correct location?
2. Are they added to the Xcode project?

**Solution**: 
- Ensure `amplifyconfiguration.json` and `awsconfiguration.json` are in the `ios/` directory
- Add them to the Xcode project target

## Verification Steps

### 1. Check Configuration Files
Verify these files exist and have correct content:
- `ios/amplifyconfiguration.json`
- `ios/awsconfiguration.json`
- `ios/Runner/Info.plist` (with camera permissions)

### 2. Check Xcode Project
1. Open `ios/Runner.xcworkspace` in Xcode
2. Verify configuration files are added to the Runner target
3. Check that camera permissions are in Info.plist

### 3. Test Session Creation
Use the debug button to test:
- Session token retrieval
- Session creation
- Any error messages

## Expected Behavior After Fix

1. **iOS**: Face liveness detector should work without sessionNotFound error
2. **Android**: Should continue working as before
3. **Debug Output**: Should show successful session creation and no errors

## If Issues Persist

1. **Check AWS Credentials**: Ensure your AWS account has Rekognition access
2. **Check Network**: Ensure the device has internet connectivity
3. **Check Backend**: Verify the backend service is working correctly
4. **Check Logs**: Look for any AWS or network-related errors in the debug output

## Files Modified

- `ios/Runner/Info.plist` - Added camera permissions
- `ios/amplifyconfiguration.json` - Updated AWS configuration
- `ios/awsconfiguration.json` - Updated AWS configuration
- `lib/src/ui/core/kyc_face_liveness_detector.dart` - Enhanced error handling
- `lib/src/ui/core/kyc_face_verification.dart` - Added debugging and platform detection
- `lib/src/services/kyc_service.dart` - Enhanced session creation logging

## Next Steps

1. Test the app on iOS device/simulator
2. Check debug output for any remaining issues
3. If problems persist, check the specific error messages in the debug output
4. Contact support with the debug information if needed 