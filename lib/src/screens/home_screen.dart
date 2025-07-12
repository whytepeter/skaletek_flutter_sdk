import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isVerifying = false;
  String _status = '';
  PermissionStatus _cameraPermissionStatus = PermissionStatus.denied;
  bool _showingPermissionDialog = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    // Check current permission status
    final status = await Permission.camera.status;

    setState(() {
      _cameraPermissionStatus = status;
    });

    // Handle permission for iOS simulator
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS) {
      if (status.isDenied || status.isPermanentlyDenied) {
        await _handleSimulatorCameraPermission();
      }
    }
  }

  Future<void> _handleSimulatorCameraPermission() async {
    if (_showingPermissionDialog) return;

    setState(() {
      _showingPermissionDialog = true;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('iOS Simulator Camera Setup'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The iOS simulator requires special setup for camera functionality:',
            ),
            SizedBox(height: 16),
            Text('1. Open Xcode'),
            Text('2. Go to Features → Camera → Custom Device...'),
            Text('3. Select a sample video file'),
            SizedBox(height: 16),
            Text('Without this setup, face liveness detection will not work.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _showingPermissionDialog = false);
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _showingPermissionDialog = false);
              await _openSimulatorCameraSettings();
            },
            child: const Text('Open Xcode'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSimulatorCameraSettings() async {
    // This is a placeholder - in a real app, you might want to:
    // 1. Open Xcode if installed
    // 2. Show instructions to open simulator settings
    if (kDebugMode) {
      print('⚠️ Please manually configure simulator camera in Xcode');
    }
  }

  void _startVerification() async {
    setState(() {
      _isVerifying = true;
      _status = 'Starting verification...';
    });

    await SkaletekKYC.instance.startVerification(
      token: "039cfd771d204bafb1ea47da0cc06164", // Replace with actual token
      userInfo: {
        "first_name": "David",
        "last_name": "Omale",
        "document_type": "PASSPORT",
        "issuing_country": "USA",
      },
      customization: {
        "doc_src": "FILE", // Use camera to capture document
        // "logo_url":
        //     "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/YouTube_Logo_2017.svg/2560px-YouTube_Logo_2017.svg.png",
        "partner_name": "YouTube",
        // "primary_color": "#126DD6",
        // "primary_color": "#ff0000",
      },
      onComplete: (success, data) {
        setState(() {
          _isVerifying = false;
        });

        if (success) {
          setState(() {
            _status = 'Verification completed successfully!';
          });
        } else {
          setState(() {
            _status =
                'Verification failed: ${data['error'] ?? 'Unknown error'}';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skaletek KYC'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user, size: 80, color: Color(0xFF1261C1)),
            const SizedBox(height: 24),
            const Text(
              'Skaletek KYC SDK Demo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This demo shows how to integrate the Skaletek KYC Flutter SDK for identity verification.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (_isVerifying)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verification in progress...'),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1261C1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Start Identity Verification'),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final Uri url = Uri.parse(
                    'https://docs.skaletek.io/ekyc/flutter-sdk/',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open documentation'),
                        ),
                      );
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View Documentation'),
              ),
            ),

            const SizedBox(height: 20),
            if (_status.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _status.contains('success')
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _status.contains('success')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _status.contains('success')
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
