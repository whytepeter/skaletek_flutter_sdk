import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:skaletek_kyc_flutter/src/utils/image_cropper.dart';
import 'app_color.dart';

class ImageFile {
  final String name;
  final int size;
  final Uint8List? bytes;
  final String path;
  final String? extension;

  ImageFile({
    required this.name,
    required this.size,
    this.bytes,
    required this.path,
    this.extension,
  });

  static Future<ImageFile> fromXFile(XFile xFile) async {
    final file = File(xFile.path);
    final bytes = await file.readAsBytes();
    final extension = xFile.name.split('.').last.toLowerCase();
    return ImageFile(
      name: xFile.name,
      size: bytes.length,
      bytes: bytes,
      path: xFile.path,
      extension: extension,
    );
  }
}

class FileInput extends StatefulWidget {
  final Function(ImageFile file)? onFileSelected;
  final VoidCallback? onFileRemoved;
  final ImageFile? selectedFile;
  final int? maxFileSize;
  final bool disabled;
  final String? errorMessage;
  final KYCService? kycService;
  final Function(String message)? onShowToast;
  final String? documentType;
  final Function(bool isScanning)? onScanningChanged;

  const FileInput({
    super.key,
    this.onFileSelected,
    this.onFileRemoved,
    this.selectedFile,
    this.maxFileSize = 5 * 1024 * 1024, // 5MB
    this.disabled = false,
    this.errorMessage,
    this.kycService,
    this.onShowToast,
    this.documentType,
    this.onScanningChanged,
  });

  @override
  State<FileInput> createState() => _FileInputState();
}

class _FileInputState extends State<FileInput> {
  ImageFile? _selectedFile;
  String? _errorMessage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.selectedFile;
  }

  @override
  void didUpdateWidget(FileInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedFile != oldWidget.selectedFile) {
      _selectedFile = widget.selectedFile;
    }
  }

  Future<void> _pickImage() async {
    if (widget.disabled) return;
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        final imageFile = await ImageFile.fromXFile(image);
        if (widget.maxFileSize != null &&
            imageFile.size > widget.maxFileSize!) {
          setState(() {
            _errorMessage = 'Image size exceeds the maximum allowed size';
          });
          return;
        }

        // Set the initial file and start detection
        setState(() {
          _selectedFile = imageFile;
          _errorMessage = null;
          _isDetecting = true;
        });

        // Call onFileSelected with the original file first
        widget.onFileSelected?.call(imageFile);
        widget.onScanningChanged?.call(true);

        // Perform document detection
        await _detectAndCropDocument(imageFile);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: ${e.toString()}';
        _isDetecting = false;
      });
      widget.onScanningChanged?.call(false);
    }
  }

  Future<void> _detectAndCropDocument(ImageFile imageFile) async {
    // Only perform detection for Passport documents
    if (widget.documentType?.toUpperCase() != 'PASSPORT') {
      setState(() {
        _isDetecting = false;
      });
      widget.onScanningChanged?.call(false);
      return;
    }

    if (widget.kycService == null) {
      setState(() {
        _isDetecting = false;
      });
      widget.onScanningChanged?.call(false);
      return;
    }

    try {
      final file = File(imageFile.path);
      final bbox = await widget.kycService!.detectDocument(file);

      if (bbox != null && bbox.length == 4) {
        safePrint('FileInput: Cropping image with bbox: $bbox');
        safePrint(
          'FileInput: Original image size: ${imageFile.bytes!.length} bytes',
        );

        // Crop the image using the bounding box
        final croppedBytes = await ImageCropper.cropImage(
          imageFile.bytes!,
          bbox,
        );

        safePrint(
          'FileInput: Cropped image size: ${croppedBytes.length} bytes',
        );
        final croppedPath = await ImageCropper.saveCroppedImage(
          croppedBytes,
          imageFile.path,
        );

        // Create new ImageFile with cropped data
        final croppedImageFile = ImageFile(
          name: 'cropped_${imageFile.name}',
          size: croppedBytes.length,
          bytes: croppedBytes,
          path: croppedPath,
          extension: imageFile.extension,
        );

        setState(() {
          _selectedFile = croppedImageFile;
          _isDetecting = false;
        });

        // Call onFileSelected with the cropped file
        widget.onFileSelected?.call(croppedImageFile);
        widget.onScanningChanged?.call(false);
      } else {
        // No bounding box found, show toast message
        widget.onShowToast?.call(
          'Please provide a valid Document type in the country',
        );
        setState(() {
          _isDetecting = false;
        });
        widget.onScanningChanged?.call(false);
      }
    } catch (e) {
      // If detection fails, keep the original file and show error
      widget.onShowToast?.call(
        'Document detection failed. Using original image.',
      );
      setState(() {
        _isDetecting = false;
      });
      widget.onScanningChanged?.call(false);
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _errorMessage = null;
    });
    widget.onFileRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildMainContainer(), _buildErrorMessage()],
    );
  }

  Widget _buildMainContainer() {
    final borderColor = _getBorderColor();

    return Opacity(
      opacity: widget.disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: widget.disabled ? null : _pickImage,
        child: Stack(
          children: [
            _buildDashedBorder(borderColor),
            _buildContent(),
            _buildDeleteButton(),
          ],
        ),
      ),
    );
  }

  Color _getBorderColor() {
    return _errorMessage != null || widget.errorMessage != null
        ? AppColor.error
        : AppColor.lightBlue;
  }

  Widget _buildDashedBorder(Color borderColor) {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: borderColor,
        borderRadius: 20,
        dashWidth: 8,
        dashSpace: 6,
        strokeWidth: 1.5,
      ),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: AppColor.background,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _selectedFile == null
            ? _buildDefaultView()
            : _buildPreviewView(),
      ),
    );
  }

  Widget _buildDefaultView() {
    return Center(
      child: Image.asset(
        'assets/images/image.png',
        width: 96,
        height: 96,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildPreviewView() {
    return Stack(
      children: [
        Image.memory(
          _selectedFile!.bytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        if (_isDetecting) _buildScanOverlay(),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Image.asset(
        'assets/images/scan.gif',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildDeleteButton() {
    if (_selectedFile == null || _isDetecting) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: widget.disabled ? null : _removeFile,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.delete, color: AppColor.error, size: 24),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null && widget.errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColor.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? widget.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  DashedBorderPainter({
    required this.color,
    this.borderRadius = 0,
    this.dashWidth = 5,
    this.dashSpace = 3,
    this.strokeWidth = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
