# Xcode Setup Guide for Face Liveness Detection

## Prerequisites
- Xcode is now open with your iOS project (`ios/Runner.xcworkspace`)
- Swift Package Manager is enabled in Flutter

## Step-by-Step Xcode Configuration

### Step 1: Add Swift Package Dependencies

1. **Open Xcode** (should already be open from the previous command)

2. **Add AWS Amplify Swift Package**:
   - In Xcode, go to **File > Add Package Dependencies...**
   - In the search field, enter: `https://github.com/aws-amplify/amplify-swift`
   - Click **Add Package**
   - Select version: **2.46.1** or later
   - Select these products:
     - ✅ **Amplify**
     - ✅ **AWSCognitoAuthPlugin**
   - Click **Add Package**

3. **Add AWS Amplify UI Liveness Package**:
   - In Xcode, go to **File > Add Package Dependencies...**
   - In the search field, enter: `https://github.com/aws-amplify/amplify-ui-swift-liveness`
   - Click **Add Package**
   - Select version: **1.3.5** or later
   - Select this product:
     - ✅ **FaceLiveness**
   - Click **Add Package**

### Step 2: Add Configuration Files to Xcode Project

1. **Add amplifyconfiguration.json**:
   - In Xcode's Project Navigator (left sidebar), right-click on the **Runner** folder
   - Select **Add Files to "Runner"...**
   - Navigate to your project's `ios/` directory
   - Select `amplifyconfiguration.json`
   - Make sure **"Add to target"** has **Runner** checked
   - Click **Add**

2. **Add awsconfiguration.json**:
   - Repeat the same process for `awsconfiguration.json`
   - Right-click on **Runner** folder
   - Select **Add Files to "Runner"...**
   - Select `awsconfiguration.json`
   - Make sure **"Add to target"** has **Runner** checked
   - Click **Add**

### Step 3: Verify Package Dependencies

1. **Check Package Dependencies**:
   - In Xcode, go to **Project Navigator**
   - Click on your project name (top of the list)
   - Select **Runner** target
   - Go to **Package Dependencies** tab
   - You should see:
     - `amplify-swift`
     - `amplify-ui-swift-liveness`

2. **Check Build Phases**:
   - Still in the **Runner** target
   - Go to **Build Phases** tab
   - Expand **Link Binary With Libraries**
   - You should see the Swift packages listed

### Step 4: Build and Test

1. **Clean Build**:
   - In Xcode, go to **Product > Clean Build Folder**
   - Then **Product > Build**

2. **Run from Flutter**:
   ```bash
   flutter run -d "iPhone 15 Pro"
   ```

## Troubleshooting

### If you see "No such module 'FaceLiveness'" error:

1. **Check Package Dependencies**:
   - Make sure both Swift packages are added correctly
   - Verify the versions are compatible

2. **Clean and Rebuild**:
   - In Xcode: **Product > Clean Build Folder**
   - In Terminal: `flutter clean && flutter pub get`

3. **Check Target Membership**:
   - Select the configuration files in Xcode
   - In the File Inspector (right panel), ensure **Target Membership** shows **Runner**

### If you see other build errors:

1. **Check iOS Deployment Target**:
   - Ensure it's set to iOS 13.0 or later
   - In Xcode: **Runner** target > **General** tab > **Deployment Info**

2. **Check Swift Version**:
   - In Xcode: **Runner** target > **Build Settings** > search for "Swift"
   - Ensure Swift Language Version is set to **Swift 5**

## Verification

After completing these steps, the `FaceLiveness` module should be available and the iOS build should succeed.

## Next Steps

1. **Configure AWS Amplify** with your actual AWS credentials
2. **Update configuration files** with real AWS values
3. **Test the face liveness detection** on iOS simulator or device

## Files Modified

- `android/app/build.gradle.kts` - Added AWS Amplify dependencies
- `ios/Runner/Info.plist` - Updated camera usage description
- `ios/amplifyconfiguration.json` - AWS Amplify configuration (placeholder)
- `ios/awsconfiguration.json` - AWS configuration (placeholder) 