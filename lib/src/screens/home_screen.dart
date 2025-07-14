import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isVerifying = false;
  String _status = '';
  bool _hasVerificationResult = false;

  void _startVerification() async {
    setState(() {
      _isVerifying = true;
      _status = 'Starting verification...';
      _hasVerificationResult = false;
    });

    final userInfo = KYCUserInfo(
      firstName: "David",
      lastName: "Omale",
      documentType: "PASSPORT",
      issuingCountry: "USA",
    );
    final customization = KYCCustomization(
      docSrc: "LIVE",
      logoUrl: null,
      partnerName: "YouTube",
      primaryColor: null,
    );

    SkaletekKYC.instance.startVerification(
      token: "039cfd771d204bafb1ea47da0cc06164",
      // token: "a1f2bbdde4974ad9808f9a748c09ed3d",
      userInfo: userInfo,
      customization: customization,
      onComplete: (result) {
        setState(() {
          _isVerifying = false;
          _hasVerificationResult = true;
          if (result['success'] == true) {
            _status = 'Verification completed successfully!';
          } else {
            _status =
                'Verification failed: ${result['status'] ?? 'Unknown error'}';
          }
        });
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

            const SizedBox(height: 20),
            if (_hasVerificationResult && _status.isNotEmpty)
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
