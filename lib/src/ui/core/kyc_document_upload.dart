/*
/// Handles document collection for identity verification with support for both
/// file upload and live camera capture with ML-powered scanning.
///
/// Features:
/// - Multi-modal input (file upload or live camera)
/// - Document type-aware front/back requirements
/// - Real-time ML scanning and validation
/// - State persistence across sessions
/// - Automatic error recovery with session refresh
/// - Secure upload via presigned URLs
///
/// Supports two modes:
/// - LIVE: Real-time camera capture with ML detection
/// - FILE: Traditional file selection from device
///
/// Usage:
/// ```dart
/// KYCDocumentUpload(
///   kycService: kycServiceInstance,
///   userInfo: userInformation,
///   customization: KYCCustomization(docSrc: 'LIVE'),
///   onNext: () => navigateToNextStep(),
/// )
/// ```
*/
import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:skaletek_kyc_flutter/src/services/error_handler_service.dart';
import 'package:skaletek_kyc_flutter/src/services/websocket_service.dart';
import 'package:skaletek_kyc_flutter/src/ui/core/camera_captuer/kyc_camera_capture.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/content.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/file_input.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';
import 'dart:developer' as developer;

/// Document types that require both front and back sides for verification
const Set<String> _documentTypesWithBackView = {
  'NATIONAL_ID',
  'RESIDENCE_PERMIT',
  'DRIVER_LICENCE',
};

/// KYC document upload widget with ML-powered scanning
///
/// Manages document collection workflow with support for file upload and live camera capture.
/// Handles state persistence, error recovery, and provides document type-aware validation.
class KYCDocumentUpload extends StatefulWidget {
  const KYCDocumentUpload({
    super.key,
    this.onNext,
    required this.kycService,
    this.userInfo,
    required this.customization,
  });

  /// Callback invoked when upload completes successfully
  final VoidCallback? onNext;

  /// KYC service for upload functionality and state management
  final KYCService kycService;

  /// User context including document type for validation requirements
  final KYCUserInfo? userInfo;

  /// Configuration defining capture mode (LIVE/FILE) and UI settings
  final KYCCustomization customization;

  @override
  State<KYCDocumentUpload> createState() => _KYCDocumentUploadState();
}

/// State management for document upload widget
///
/// Manages document selection, upload progress, ML scanning, WebSocket connections,
/// and error handling with state persistence across app lifecycle.

class _KYCDocumentUploadState extends State<KYCDocumentUpload> {
  /// Selected front document file with metadata
  ImageFile? _frontDocument;

  /// Selected back document file (required for certain document types)
  ImageFile? _backDocument;

  /// Presigned URL configuration for secure cloud uploads
  PresignedUrl? _presignedUrl;

  /// Loading state for initial setup operations
  bool _isLoading = false;

  /// Upload state for active document operations
  bool _isUploading = false;

  /// Scanning state for front document ML processing
  bool _isFrontScanning = false;

  /// Scanning state for back document ML processing
  bool _isBackScanning = false;

  /// Global key for front document file input
  final GlobalKey<FileInputState> _frontFileInputKey =
      GlobalKey<FileInputState>();

  /// Global key for back document file input
  final GlobalKey<FileInputState> _backFileInputKey =
      GlobalKey<FileInputState>();

  /// WebSocket service for real-time ML document detection (LIVE mode only)
  WebSocketService? _wsService;

  /// Centralized error handling service
  static final ErrorHandlerService _errorHandler = ErrorHandlerService();

  @override
  void initState() {
    super.initState();
    _initializeWebSocketService();
    _initializeDocumentUpload();
  }

  /// Initializes WebSocket service for ML document detection
  ///
  /// Creates and connects WebSocket service for LIVE mode only. The connection
  /// is shared across camera capture instances for optimal resource usage.
  void _initializeWebSocketService() {
    final docSrc = widget.customization.docSrc.toUpperCase();

    // Only initialize WebSocket service for LIVE camera captures
    if (docSrc == 'LIVE') {
      _wsService = WebSocketService();
      // Start connection in background - camera captures will reuse this connection
      _wsService!.connect();

      // Optional: Listen to connection status for debugging
      _wsService!.statusStream.listen((status) {
        developer.log('WebSocket status in document upload: $status');
      });

      developer.log('WebSocket service initialized for LIVE document source');
    } else {
      developer.log('WebSocket service not needed for docSrc: $docSrc');
    }
  }

  @override
  void dispose() {
    // Clean up WebSocket service if it was initialized
    _wsService?.dispose();
    super.dispose();
  }

  /// Initializes document upload workflow
  ///
  /// Performs parallel initialization of presigned URLs and state restoration
  /// to minimize wait time and provide seamless experience.
  Future<void> _initializeDocumentUpload() async {
    await Future.wait([_getPresignedUrls(), _restoreDocumentImages()]);
  }

  /// Handles errors with automatic session refresh when needed
  ///
  /// Processes errors and performs session refresh for authentication issues.
  /// Returns true if error was resolved, false if user intervention required.
  Future<bool> _handleError(
    dynamic error, {
    String context = 'documentUpload',
  }) async {
    final errorInfo = _errorHandler.processError(error, context: context);

    if (_errorHandler.requiresSessionRefresh(errorInfo)) {
      return await _refreshSession();
    } else {
      final userMessage = _errorHandler.getUserMessage(errorInfo);
      widget.kycService.showSnackbar(userMessage);
      return false;
    }
  }

  /// Refresh the session by clearing presigned URL and fetching new ones
  Future<bool> _refreshSession() async {
    safePrint('Session expired, refreshing presigned URL...');

    await widget.kycService.stateProvider?.clearPresignedUrl();
    setState(() {
      _presignedUrl = null;
    });

    try {
      await _getPresignedUrls();
      widget.kycService.showSnackbar(
        'Session refreshed. Please try uploading again.',
      );
      return true;
    } catch (refreshError) {
      safePrint('Failed to refresh presigned URL: $refreshError');
      widget.kycService.showSnackbar(
        'Failed to refresh session. Please try again.',
      );
      return false;
    }
  }

  /// Fetch presigned URLs for document upload
  Future<void> _getPresignedUrls() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Try to get from global state first
      final presignedUrlFromState =
          widget.kycService.stateProvider?.presignedUrl;
      if (presignedUrlFromState != null) {
        setState(() {
          _presignedUrl = presignedUrlFromState;
          _isLoading = false;
        });
        safePrint('Presigned URL available from state');
        return;
      }

      // Fetch new presigned URL from service
      final presignedUrl = await widget.kycService.getPresignedUrls();
      safePrint('Presigned URL fetched successfully');

      setState(() {
        _presignedUrl = presignedUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      rethrow;
    }
  }

  /// Restore previously selected document images from state
  Future<void> _restoreDocumentImages() async {
    final provider = widget.kycService.stateProvider;

    // Helper function to restore a single document
    Future<void> restoreDocument({
      required String? documentPath,
      required Function(ImageFile file) setDocument,
    }) async {
      if (documentPath == null) return;

      final file = File(documentPath);
      if (!await file.exists()) return;

      try {
        final bytes = await file.readAsBytes();
        final imageFile = ImageFile(
          name: file.uri.pathSegments.last,
          size: bytes.length,
          bytes: bytes,
          path: file.path,
          extension: file.uri.pathSegments.last.split('.').last,
        );

        setState(() {
          setDocument(imageFile);
        });
      } catch (e) {
        safePrint('Failed to restore document image: $e');
      }
    }

    await Future.wait([
      restoreDocument(
        documentPath: provider?.frontDocumentPath,
        setDocument: (file) => _frontDocument = file,
      ),
      restoreDocument(
        documentPath: provider?.backDocumentPath,
        setDocument: (file) => _backDocument = file,
      ),
    ]);
  }

  /// Uploads documents with validation, error handling, and progress tracking
  ///
  /// Validates documents, uploads them in parallel, and handles errors with
  /// automatic session refresh. Updates UI state and triggers navigation on success.
  Future<void> _uploadDocuments() async {
    if (!_validateDocuments()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      await _ensurePresignedUrl();
      await _performDocumentUploads();
      await _markDocumentsAsUploaded();

      safePrint('Documents uploaded successfully');
      widget.onNext?.call();
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      safePrint('Upload failed: ${e.toString()}');

      final sessionRefreshed = await _handleError(
        e,
        context: 'uploadDocuments',
      );

      if (sessionRefreshed) {
        return;
      }
    }
  }

  /// Validates that required documents are selected based on document type
  ///
  /// Front document is always required. Back document is required for certain
  /// document types (ID cards, permits, licenses). Shows user guidance for missing documents.
  bool _validateDocuments() {
    if (_frontDocument == null) {
      widget.kycService.showSnackbar('Please select a front document');
      return false;
    }

    final documentType = widget.userInfo?.documentType ?? '';
    final requiresBackView = _hasBackView(documentType);

    if (requiresBackView && _backDocument == null) {
      widget.kycService.showSnackbar('Please select a back document');
      return false;
    }

    return true;
  }

  /// Ensure presigned URL is available
  Future<void> _ensurePresignedUrl() async {
    if (_presignedUrl == null) {
      safePrint('No presigned URL, fetching...');
      await _getPresignedUrls();
    }

    if (_presignedUrl == null) {
      throw Exception('Failed to get presigned URLs');
    }
  }

  /// Perform the actual document uploads
  Future<void> _performDocumentUploads() async {
    final provider = widget.kycService.stateProvider;
    final uploadTasks = <Future<void>>[];

    // Debug: Log presigned URL information
    safePrint('Performing document uploads...');
    safePrint('Presigned URL available: ${_presignedUrl != null}');
    if (_presignedUrl != null) {
      safePrint('Front URL: ${_presignedUrl!.front.url}');
      safePrint('Back URL: ${_presignedUrl!.back.url}');
    }
    safePrint('Front document: ${_frontDocument?.path}');
    safePrint('Back document: ${_backDocument?.path}');
    safePrint('Front uploaded: ${provider?.frontDocumentUploaded}');
    safePrint('Back uploaded: ${provider?.backDocumentUploaded}');

    // Helper function to add upload task if document needs uploading
    void addUploadTaskIfNeeded({
      required ImageFile? document,
      required bool isUploaded,
      required Future<void> Function(File file, PresignedUrl url)
      uploadFunction,
    }) {
      if (document != null && !isUploaded) {
        final file = File(document.path);
        safePrint('Adding upload task for file: ${file.path}');
        uploadTasks.add(uploadFunction(file, _presignedUrl!));
      } else if (document != null) {
        safePrint('Document already uploaded, skipping...');
      }
    }

    // Add front document upload task
    addUploadTaskIfNeeded(
      document: _frontDocument,
      isUploaded: provider?.frontDocumentUploaded ?? false,
      uploadFunction: widget.kycService.uploadFrontDocument,
    );

    // Add back document upload task
    addUploadTaskIfNeeded(
      document: _backDocument,
      isUploaded: provider?.backDocumentUploaded ?? false,
      uploadFunction: widget.kycService.uploadBackDocument,
    );

    safePrint('Total upload tasks: ${uploadTasks.length}');

    if (uploadTasks.isNotEmpty) {
      await Future.wait(uploadTasks);
    }
  }

  /// Mark documents as uploaded in state
  Future<void> _markDocumentsAsUploaded() async {
    await widget.kycService.stateProvider?.markDocumentsAsUploaded();
  }

  /// Check if document type requires back view
  bool _hasBackView(String documentType) {
    return _documentTypesWithBackView.contains(documentType.toUpperCase());
  }

  /// Shows full-screen camera capture with ML-powered document detection
  ///
  /// Presents immersive camera interface with real-time ML feedback for optimal
  /// document positioning. Captured images are automatically processed and routed
  /// to the appropriate document slot (front/back).
  void _showFullScreenCameraSheet({required bool isFront}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      enableDrag: false,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: KYCCameraCapture(
          wsService: _wsService, // Pass WebSocket service to camera
          onCapture: (file) async {
            final bytes = await file.readAsBytes();
            final imageFile = ImageFile(
              name: file.name,
              size: bytes.length,
              bytes: bytes,
              path: file.path,
              extension: file.name.split('.').last,
            );

            if (context.mounted) {
              Navigator.of(context).pop();
            }

            if (isFront) {
              _frontFileInputKey.currentState?.setFileAndScan(
                imageFile,
                widget.userInfo?.documentType,
                widget.kycService,
              );
            } else {
              _backFileInputKey.currentState?.setFileAndScan(
                imageFile,
                widget.userInfo?.documentType,
                widget.kycService,
              );
            }
          },
        ),
      ),
    );
  }

  /// Builds document input widget that adapts based on capture mode
  ///
  /// LIVE mode includes camera capture button, FILE mode uses traditional file picker.
  /// Maintains consistent layout and provides appropriate callbacks for each mode.
  Widget _buildDocumentView({
    required String title,
    required ImageFile? selectedFile,
    required Function(ImageFile file) onFileSelected,
    required VoidCallback onFileRemoved,
    required bool disabled,
    required Function(bool isScanning) onScanningChanged,
    required bool isFront,
  }) {
    final docSrc = widget.customization.docSrc.toUpperCase();
    if (docSrc == 'LIVE') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StyledTitle(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FileInput(
            key: isFront ? _frontFileInputKey : _backFileInputKey,
            selectedFile: selectedFile,
            onFileSelected: onFileSelected,
            onFileRemoved: onFileRemoved,
            disabled: disabled,
            kycService: widget.kycService,
            onShowToast: widget.kycService.showSnackbar,
            documentType: widget.userInfo?.documentType,
            onScanningChanged: onScanningChanged,
            showCameraIcon: true,
            onCameraPressed: () {
              _showFullScreenCameraSheet(isFront: isFront);
            },
          ),
        ],
      );
    }
    // Fallback to file input for non-LIVE
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyledTitle(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        FileInput(
          selectedFile: selectedFile,
          onFileSelected: onFileSelected,
          onFileRemoved: onFileRemoved,
          disabled: disabled,
          kycService: widget.kycService,
          onShowToast: widget.kycService.showSnackbar,
          documentType: widget.userInfo?.documentType,
          onScanningChanged: onScanningChanged,
        ),
      ],
    );
  }

  /// Build the front document view
  Widget _buildFrontView() {
    return _buildDocumentView(
      title: 'Front view',
      selectedFile: _frontDocument,
      onFileSelected: _handleFrontDocumentSelected,
      onFileRemoved: _handleFrontDocumentRemoved,
      disabled: _isUploading,
      onScanningChanged: _setFrontScanning,
      isFront: true,
    );
  }

  /// Build the back document view
  Widget _buildBackView() {
    return _buildDocumentView(
      title: 'Back view',
      selectedFile: _backDocument,
      onFileSelected: _handleBackDocumentSelected,
      onFileRemoved: _handleBackDocumentRemoved,
      disabled: _isUploading,
      onScanningChanged: _setBackScanning,
      isFront: false,
    );
  }

  /// Handles document selection and removal with state coordination
  ///
  /// Updates both local widget state and global state provider to maintain
  /// consistency. Resets upload status when documents change.
  void _handleDocumentAction({
    required bool isFront,
    ImageFile? file,
    bool isRemoval = false,
  }) {
    final isFrontDocument = isFront;

    setState(() {
      if (isFrontDocument) {
        _frontDocument = isRemoval ? null : file;
      } else {
        _backDocument = isRemoval ? null : file;
      }
    });

    final provider = widget.kycService.stateProvider;
    if (isFrontDocument) {
      provider?.setFrontDocumentPath(isRemoval ? null : file?.path);
      provider?.setFrontDocumentUploaded(false);
    } else {
      provider?.setBackDocumentPath(isRemoval ? null : file?.path);
      provider?.setBackDocumentUploaded(false);
    }
  }

  /// Handle front document selection
  void _handleFrontDocumentSelected(ImageFile file) {
    _handleDocumentAction(isFront: true, file: file);
  }

  /// Handle front document removal
  void _handleFrontDocumentRemoved() {
    _handleDocumentAction(isFront: true, isRemoval: true);
  }

  /// Handle back document selection
  void _handleBackDocumentSelected(ImageFile file) {
    _handleDocumentAction(isFront: false, file: file);
  }

  /// Handle back document removal
  void _handleBackDocumentRemoved() {
    _handleDocumentAction(isFront: false, isRemoval: true);
  }

  /// Set front document scanning state
  void _setFrontScanning(bool isScanning) {
    setState(() {
      _isFrontScanning = isScanning;
    });
  }

  /// Set back document scanning state
  void _setBackScanning(bool isScanning) {
    setState(() {
      _isBackScanning = isScanning;
    });
  }

  /// Checks if user can proceed to next step
  ///
  /// Validates that required documents are selected and no operations are in progress.
  /// Front document is always required, back document only for certain types.
  bool get _canProceed {
    if (_isLoading || _isUploading || _isFrontScanning || _isBackScanning) {
      return false;
    }

    final provider = widget.kycService.stateProvider;
    final documentType = widget.userInfo?.documentType ?? '';
    final requiresBackView = _hasBackView(documentType);

    // Helper function to check if a document is ready
    bool isDocumentReady(ImageFile? document, bool isUploaded) {
      return document != null && (isUploaded || !_isUploading);
    }

    // Front document must be selected and ready
    final frontReady = isDocumentReady(
      _frontDocument,
      provider?.frontDocumentUploaded ?? false,
    );

    // Back document logic based on document type requirements
    final backReady = requiresBackView
        ? isDocumentReady(
            _backDocument,
            provider?.backDocumentUploaded ?? false,
          )
        : (_backDocument == null ||
              provider?.backDocumentUploaded == true ||
              !_isUploading);

    return frontReady && backReady;
  }

  /// Handles continue button press and initiates upload if ready
  void _handleContinuePressed() {
    if (_canProceed) {
      _uploadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: KYCContent(
        step: KYCStep.document,
        userInfo: widget.userInfo,
        footer: KYCButton(
          text: 'Continue',
          block: true,
          loading: _isUploading,
          disabled: !_canProceed,
          onPressed: _handleContinuePressed,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFrontView(),
              if (_hasBackView(widget.userInfo?.documentType ?? '')) ...[
                const SizedBox(height: 24),
                _buildBackView(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
