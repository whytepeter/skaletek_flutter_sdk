# Face Liveness Detector Setup Guide

This guide explains how to set up the AWS Rekognition Face Liveness detection in your Flutter app.

## Prerequisites

1. **AWS Account**: You need an AWS account with access to:
   - AWS Rekognition
   - AWS Cognito (for authentication)
   - AWS Amplify

2. **Backend Service**: You need a backend service that can create Face Liveness sessions using AWS Rekognition.

## Current Setup Status

✅ **Flutter Configuration**: The Flutter app is configured with the `face_liveness_detector` package.

✅ **Platform Configuration**: 
- Android: Updated to use `FlutterFragmentActivity` and compileSdk 35
- iOS: Updated to iOS 13.0 minimum and pod dependencies installed
- Camera permissions added to Android manifest

✅ **Error Handling**: The app includes proper error handling for unsupported platforms and missing configurations.

## Required AWS Configuration

### 1. AWS Amplify Setup

You need to configure AWS Amplify in your project. Follow these steps:

1. **Install AWS Amplify CLI**:
   ```bash
   npm install -g @aws-amplify/cli
   ```

2. **Configure Amplify**:
   ```bash
   amplify configure
   ```

3. **Initialize Amplify in your project**:
   ```bash
   amplify init
   ```

4. **Add Authentication**:
   ```bash
   amplify add auth
   ```

5. **Push the configuration**:
   ```bash
   amplify push
   ```

### 2. Update Configuration Files

Replace the placeholder configuration files with your actual AWS configuration:

#### Android Configuration
File: `android/app/src/main/res/raw/amplifyconfiguration.json`
```json
{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify/cli",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "YOUR_ACTUAL_IDENTITY_POOL_ID",
              "Region": "us-east-1"
            }
          }
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "YOUR_ACTUAL_USER_POOL_ID",
            "AppClientId": "YOUR_ACTUAL_APP_CLIENT_ID",
            "Region": "us-east-1"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH"
          }
        }
      }
    }
  }
}
```

#### iOS Configuration
Files: 
- `ios/amplifyconfiguration.json`
- `ios/awsconfiguration.json`

Update both files with your actual AWS configuration values.

### 3. Backend Integration

Your backend service needs to:

1. **Create Face Liveness Sessions**: Use AWS Rekognition to create liveness sessions
2. **Return Session Tokens**: Provide session tokens to the Flutter app
3. **Handle Results**: Process liveness check results

The current KYC service expects:
- `createSession()` method to return a liveness token
- `getResult()` method to fetch liveness results

## Testing

### Supported Platforms
- ✅ iOS (13.0+)
- ✅ Android (API 24+)

### Unsupported Platforms
- ❌ Web
- ❌ Desktop (macOS, Windows, Linux)

### Testing on Mobile

1. **iOS Simulator**:
   ```bash
   flutter run -d "iPhone 15 Pro"
   ```

2. **Android Emulator**:
   ```bash
   flutter run -d "sdk gphone64 arm64"
   ```

### Testing on Unsupported Platforms

The app includes a simulation mode for testing on unsupported platforms:
- Shows "Platform Not Supported" message
- Provides "Simulate Success" button for testing the flow

## Troubleshooting

### Common Issues

1. **MissingPluginException**: 
   - Ensure you're running on iOS or Android
   - Check that AWS Amplify is properly configured
   - Verify configuration files are in the correct locations

2. **Camera Permission Issues**:
   - Android: Check `AndroidManifest.xml` has camera permissions
   - iOS: Ensure camera usage description is added to `Info.plist`

3. **AWS Configuration Issues**:
   - Verify your AWS credentials are correct
   - Check that your AWS account has Rekognition access
   - Ensure Cognito pools are properly configured

### Debug Steps

1. Check platform support:
   ```dart
   print('Platform: ${defaultTargetPlatform}');
   print('Is Web: ${kIsWeb}');
   ```

2. Verify plugin availability:
   ```dart
   try {
     const MethodChannel channel = MethodChannel('face_liveness_event');
     await channel.invokeMethod('check');
     print('Plugin available');
   } catch (e) {
     print('Plugin error: $e');
   }
   ```

## Next Steps

1. **Configure AWS Amplify** with your actual AWS account
2. **Update configuration files** with real AWS values
3. **Test on mobile devices** or simulators
4. **Integrate with your backend** for session creation and result handling

## Files Modified

- `pubspec.yaml` - Added face_liveness_detector dependency
- `android/app/build.gradle.kts` - Updated compileSdk to 35
- `android/app/src/main/kotlin/com/example/skaletek_kyc/MainActivity.kt` - Changed to FlutterFragmentActivity
- `android/app/src/main/AndroidManifest.xml` - Added camera permissions
- `ios/Podfile` - Updated iOS version to 13.0
- `lib/src/ui/core/kyc_face_liveness_detector.dart` - Created face liveness widget
- `lib/src/ui/core/kyc_face_verification.dart` - Integrated face liveness detector
- `lib/src/services/kyc_service.dart` - Added getSessionToken method 