import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/app_color.dart';
import 'detection_checks_list.dart';
import 'feedback_box.dart';

enum FeedbackState { info, error, success }

class KYCCameraCapture extends StatefulWidget {
  final void Function(XFile)? onCapture;
  final FeedbackState feedbackState;
  final String feedbackText;
  final DetectionChecks detectionChecks;

  const KYCCameraCapture({
    super.key,
    this.onCapture,
    this.feedbackState = FeedbackState.info,
    this.feedbackText = 'Fit image in the box',
    this.detectionChecks = const DetectionChecks(),
  });

  @override
  State<KYCCameraCapture> createState() => _KYCCameraCaptureState();
}

class _KYCCameraCaptureState extends State<KYCCameraCapture> {
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _capture() async {
    if (_controller != null && _controller!.value.isInitialized) {
      final file = await _controller!.takePicture();
      widget.onCapture?.call(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rectWidth = size.width * 0.9;
    final rectHeight = 220.0;
    final rectYOffset = 100.0;
    final rectTop = (size.height - rectHeight) / 2 - rectYOffset;
    return SizedBox.expand(
      child: Stack(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_controller!)),
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: _buildRectangleOverlay(rectWidth, rectHeight, rectYOffset),
            ),
          // Rectangle border (cutout)
          Positioned(
            left: (size.width - rectWidth) / 2,
            top: rectTop,
            width: rectWidth,
            height: rectHeight,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          DetectionChecksList(
            detectionChecks: widget.detectionChecks,
            top: rectTop + rectHeight + 24,
          ),
          FeedbackBox(
            feedbackState: widget.feedbackState,
            feedbackText: widget.feedbackText,
          ),
          _buildCloseButton(),
          _buildCaptureButton(),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _capture,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColor.light, width: 1),
            ),
            child: Icon(Icons.camera_alt, color: AppColor.primary, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 32,
      right: 5,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
                side: BorderSide(color: AppColor.light),
              ),
            ),
            icon: Icon(Icons.close, color: Colors.grey[700], size: 24),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 24,
            tooltip: 'Close',
          ),
        ),
      ),
    );
  }

  Widget _buildRectangleOverlay(
    double rectWidth,
    double rectHeight,
    double rectYOffset,
  ) {
    return _RectangleOverlay(
      rectWidth: rectWidth,
      rectHeight: rectHeight,
      rectYOffset: rectYOffset,
    );
  }
}

class _RectangleOverlay extends StatelessWidget {
  final double rectWidth;
  final double rectHeight;
  final double rectYOffset;

  const _RectangleOverlay({
    required this.rectWidth,
    required this.rectHeight,
    required this.rectYOffset,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - rectYOffset),
      width: rectWidth,
      height: rectHeight,
    );
    return CustomPaint(
      size: size,
      painter: _RectangleOverlayPainter(rect: rect),
    );
  }
}

class _RectangleOverlayPainter extends CustomPainter {
  final Rect rect;
  _RectangleOverlayPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(10)));
    final finalPath = Path.combine(PathOperation.difference, overlay, cutout);
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
