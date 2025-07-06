import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/kyc_config.dart';
import '../models/kyc_result.dart';

class KYCService {
  static const String _baseUrl =
      'https://api.skaletek.com/kyc'; // Replace with actual API URL
  KYCConfig? _config;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> initialize(KYCConfig config) async {
    _config = config;
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (_config?.customization.docSrc == 'LIVE') {
      await Permission.camera.request();
    }
    await Permission.photos.request();
  }

  Future<KYCResult> captureDocument() async {
    try {
      if (_config?.customization.docSrc == 'LIVE') {
        return await _captureFromCamera();
      } else {
        return await _pickFromGallery();
      }
    } catch (e) {
      return KYCResult.failure(error: 'Failed to capture document: $e');
    }
  }

  Future<KYCResult> _captureFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) {
        return KYCResult.failure(error: 'No image captured');
      }

      return await _uploadDocument(File(image.path));
    } catch (e) {
      return KYCResult.failure(error: 'Camera capture failed: $e');
    }
  }

  Future<KYCResult> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) {
        return KYCResult.failure(error: 'No image selected');
      }

      return await _uploadDocument(File(image.path));
    } catch (e) {
      return KYCResult.failure(error: 'Gallery selection failed: $e');
    }
  }

  Future<KYCResult> _uploadDocument(File imageFile) async {
    try {
      if (_config == null) {
        return KYCResult.failure(error: 'Service not initialized');
      }

      final uri = Uri.parse('$_baseUrl/upload-document');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${_config!.token}'
        ..headers['Content-Type'] = 'multipart/form-data'
        ..fields.addAll({
          'first_name': _config!.userInfo.firstName,
          'last_name': _config!.userInfo.lastName,
          'document_type': _config!.userInfo.documentType,
          'issuing_country': _config!.userInfo.issuingCountry,
          ..._config!.customization.toMap(),
        })
        ..files.add(
          await http.MultipartFile.fromPath('document', imageFile.path),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 200) {
        return KYCResult.success(status: data['status'], data: data);
      } else {
        return KYCResult.failure(
          error: data['error'] ?? 'Upload failed',
          errorCode: data['error_code'],
          data: data,
        );
      }
    } catch (e) {
      return KYCResult.failure(error: 'Upload failed: $e');
    }
  }

  Future<KYCResult> verifyFace() async {
    try {
      if (_config == null) {
        return KYCResult.failure(error: 'Service not initialized');
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) {
        return KYCResult.failure(error: 'No face image captured');
      }

      final uri = Uri.parse('$_baseUrl/verify-face');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${_config!.token}'
        ..files.add(
          await http.MultipartFile.fromPath('face_image', image.path),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 200) {
        return KYCResult.success(status: data['status'], data: data);
      } else {
        return KYCResult.failure(
          error: data['error'] ?? 'Face verification failed',
          errorCode: data['error_code'],
          data: data,
        );
      }
    } catch (e) {
      return KYCResult.failure(error: 'Face verification failed: $e');
    }
  }

  Future<KYCResult> getVerificationStatus(String verificationId) async {
    try {
      if (_config == null) {
        return KYCResult.failure(error: 'Service not initialized');
      }

      final uri = Uri.parse('$_baseUrl/status/$verificationId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config!.token}',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return KYCResult.success(status: data['status'], data: data);
      } else {
        return KYCResult.failure(
          error: data['error'] ?? 'Failed to get status',
          errorCode: data['error_code'],
          data: data,
        );
      }
    } catch (e) {
      return KYCResult.failure(error: 'Status check failed: $e');
    }
  }
}
