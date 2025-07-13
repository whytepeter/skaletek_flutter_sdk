# Skaletek KYC Flutter SDK

A Flutter SDK for integrating Skaletek's Know Your Customer (KYC) verification services.

## Features
- Document Verification: Capture or upload ID documents (passport, driver's license, ID card)
- Face Verification: Live face liveness detection
- Customizable UI: Brand your verification flow with your company logo and colors
- Cross-platform: Works on iOS and Android
- Easy Integration: Simple API with comprehensive error handling

## Installation
Add to your `pubspec.yaml`:
```yaml
dependencies:
  skaletek_kyc_flutter: ^1.0.0
```

Then run:
```sh
flutter pub get
```

## Usage
Import the SDK:
```dart
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';
```

### Start Verification
```dart
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

SkaletekKYC.instance.startVerification(
  token: "your_auth_token_here",
  userInfo: userInfo,
  customization: customization,
  onComplete: (success, data) {
    if (success) {
      print('Verification successful!');
    } else {
      print('Verification failed: \\${data['error']}');
    }
  },
);
```

## Example
See the `example/` directory for a complete Flutter app using the SDK.

## API Reference
- `startVerification`: Starts the KYC flow using model objects.
- `resetKYCState`: Resets the KYC state (for testing or new sessions).

## Changelog
See [CHANGELOG.md](CHANGELOG.md) for version history.

## License
MIT
