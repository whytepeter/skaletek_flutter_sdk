# Skaletek KYC Flutter SDK

A Flutter SDK for integrating Skaletek's Know Your Customer (KYC) verification services.

## Features

- **Document Verification**: Capture or upload ID documents (passport, driver's license, ID card)
- **Face Verification**: Live face liveness detection
- **Customizable UI**: Brand your verification flow with your company logo and colors
- **Cross-platform**: Works on iOS and Android
- **Easy Integration**: Simple API with comprehensive error handling

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  skaletek_kyc_flutter: ^1.0.0
```

### Platform Setup

#### Android (`android/app/build.gradle.kts`)
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
    }
}
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access needed for ID verification</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo access needed to select ID documents</string>
```

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';

void _startVerification() async {
  await SkaletekKYC.instance.startVerification(
    token: "your_auth_token_here",
    userInfo: {
      "first_name": "John",
      "last_name": "Doe",
      "document_type": "PASSPORT",
      "issuing_country": "USA"
    },
    customization: {
      "doc_src": "LIVE",
      "logo_url": "https://yourcompany.com/logo.svg",
      "partner_name": "Your Company",
      "primary_color": "#1261C1"
    },
    onComplete: (success, data) {
      if (success) {
        print('Verification successful!');
      } else {
        print('Verification failed: ${data['error']}');
      }
    },
  );
}
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';

class KYCScreen extends StatefulWidget {
  @override
  _KYCScreenState createState() => _KYCScreenState();
}

class _KYCScreenState extends State<KYCScreen> {
  bool _isVerifying = false;
  String _status = '';

  void _startKYCVerification() async {
    setState(() {
      _isVerifying = true;
      _status = 'Starting verification...';
    });

    await SkaletekKYC.instance.startVerification(
      token: "your_auth_token_here",
      userInfo: {
        "first_name": "John",
        "last_name": "Doe",
        "document_type": "PASSPORT",
        "issuing_country": "USA"
      },
      customization: {
        "doc_src": "LIVE", // Use camera to capture document
        "logo_url": "https://yourcompany.com/logo.svg",
        "partner_name": "Your Company",
        "primary_color": "#1261C1"
      },
      onComplete: (success, data) {
        setState(() {
          _isVerifying = false;
        });
        
        if (success) {
          setState(() {
            _status = 'Verification completed successfully!';
          });
          // Navigate to success screen or update UI
          _showSuccessDialog();
        } else {
          setState(() {
            _status = 'Verification failed: ${data['error'] ?? 'Unknown error'}';
          });
          // Show error message or retry option
          _showErrorDialog(data['error'] ?? 'Unknown error');
        }
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success!'),
        content: Text('Your identity has been verified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verification Failed'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'), 
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startKYCVerification(); // Retry
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('KYC Verification')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isVerifying)
              CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _startKYCVerification,
                child: Text('Start Identity Verification'),
              ),
            SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
```

## Configuration Options

### User Info (Required)
```dart
{
  "first_name": "John",
  "last_name": "Doe",
  "document_type": "PASSPORT", // PASSPORT, DRIVER_LICENSE, ID_CARD
  "issuing_country": "USA" // ISO country code
}
```

### Customization Options
```dart
{
  "doc_src": "LIVE", // "LIVE" for camera, "FILE" for upload
  "logo_url": "https://yourcompany.com/logo.svg", // Optional
  "logo_width": "250px", // Optional
  "logo_height": "70px", // Optional
  "partner_name": "Your Company", // Optional
  "partner_phone": "1234567890", // Optional
  "partner_email": "support@yourcompany.com", // Optional
  "help_url": "https://yourcompany.com/help", // Optional
  "primary_color": "#1261C1" // Optional, hex color
}
```

## Document Sources

### Live Camera Capture
```dart
"doc_src": "LIVE" // SDK opens camera to capture ID document
```

### File Upload
```dart
"doc_src": "FILE" // User selects existing photo from gallery
```

## Handling Results

The `onComplete` callback provides the verification result:

```dart
onComplete: (bool success, Map<String, dynamic> data) {
  if (success) {
    // Verification completed successfully
    // data contains verification details
    print('Status: ${data['status']}');
  } else {
    // Verification failed
    // data contains error information
    print('Error: ${data['error']}');
    print('Error Code: ${data['error_code']}');
  }
}
```

## Common Error Handling

```dart
onComplete: (success, data) {
  if (!success) {
    String error = data['error'] ?? 'Unknown error';
    
    if (error.contains('camera')) {
      // Handle camera permission issues
      _showCameraPermissionDialog();
    } else if (error.contains('network')) {
      // No internet connection
      _showNetworkErrorDialog();
    } else if (error.contains('document')) {
      // Document not clear or invalid
      _showDocumentErrorDialog();
    } else if (error.contains('face')) {
      // Face liveness failed
      _showFaceVerificationErrorDialog();
    } else {
      // Generic error
      _showGenericErrorDialog(error);
    }
  }
}
```

## API Reference

### SkaletekKYC.instance.startVerification()
```dart
Future<void> startVerification({
  required String token,
  required Map<String, String> userInfo,
  required Map<String, String> customization,
  required Function(bool success, Map<String, dynamic> data) onComplete,
})
```

## Using Model Classes

For better type safety, you can also use the provided model classes:

```dart
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';

final userInfo = KYCUserInfo(
  firstName: "John",
  lastName: "Doe",
  documentType: "PASSPORT",
  issuingCountry: "USA",
);

final customization = KYCCustomization(
  docSrc: "LIVE",
  logoUrl: "https://yourcompany.com/logo.svg",
  partnerName: "Your Company",
  primaryColor: "#1261C1",
);

await SkaletekKYC.instance.startVerificationWithModels(
  token: "your_auth_token_here",
  userInfo: userInfo,
  customization: customization,
  onComplete: (success, data) {
    // Handle result
  },
);
```

## Permissions

The SDK requires the following permissions:

### Android
- Camera permission for document capture
- Storage permission for file selection

### iOS
- Camera usage description
- Photo library usage description

## Error Codes

Common error codes and their meanings:

- `CAMERA_PERMISSION_DENIED`: Camera permission not granted
- `PHOTO_PERMISSION_DENIED`: Photo library permission not granted
- `NETWORK_ERROR`: No internet connection or API unreachable
- `INVALID_DOCUMENT`: Document image is unclear or invalid
- `FACE_VERIFICATION_FAILED`: Face liveness detection failed
- `TOKEN_EXPIRED`: Authentication token has expired
- `INVALID_TOKEN`: Authentication token is invalid

## Support

For support and questions, please contact:
- Email: support@skaletek.com
- Documentation: https://docs.skaletek.com
- GitHub Issues: [Create an issue](https://github.com/skaletek/skaletek-kyc-flutter/issues)

## License

This SDK is licensed under the MIT License. See the LICENSE file for details.
