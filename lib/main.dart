import 'package:flutter/material.dart';
import 'src/skaletek_kyc_sdk.dart';
import 'src/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skaletek KYC Demo',
      navigatorKey: SkaletekKYC.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1261C1)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
