import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/skaletek_kyc_flutter.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:skaletek_kyc_flutter/src/services/error_handler_service.dart';
import 'package:skaletek_kyc_flutter/src/ui/core/camera_captuer/kyc_camera_capture.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/content.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/file_input.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';
import 'dart:developer' as developer;

/// Document types that require back view for verification
const Set<String> _documentTypesWithBackView = {
  'NATIONAL_ID',
  'RESIDENCE_PERMIT',
  'DRIVER_LICENCE',
};

/// A widget that handles document upload functionality for KYC verification.
///
/// This widget manages the upload of front and back document views,
/// handles presigned URL management, and provides a user-friendly interface
/// for document selection and upload.
class KYCDocumentUpload extends StatefulWidget {
  const KYCDocumentUpload({
    super.key,
    this.onNext,
    required this.kycService,
    this.userInfo,
    required this.customization,
  });

  final VoidCallback? onNext;
  final KYCService kycService;
  final KYCUserInfo? userInfo;
  final KYCCustomization customization;

  @override
  State<KYCDocumentUpload> createState() => _KYCDocumentUploadState();
}

class _KYCDocumentUploadState extends State<KYCDocumentUpload> {
  ImageFile? _frontDocument;
  ImageFile? _backDocument;
  PresignedUrl? _presignedUrl;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isFrontScanning = false;
  bool _isBackScanning = false;

  // Add GlobalKeys for FileInput
  final GlobalKey<FileInputState> _frontFileInputKey =
      GlobalKey<FileInputState>();
  final GlobalKey<FileInputState> _backFileInputKey =
      GlobalKey<FileInputState>();

  // Centralized error handler instance
  static final ErrorHandlerService _errorHandler = ErrorHandlerService();

  @override
  void initState() {
    super.initState();
    _initializeDocumentUpload();
  }

  /// Initialize the document upload process by fetching presigned URLs
  /// and restoring any previously selected documents
  Future<void> _initializeDocumentUpload() async {
    await Future.wait([_getPresignedUrls(), _restoreDocumentImages()]);
  }

  /// Centralized error handling method that processes errors and handles
  /// session refresh when needed
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

  /// Upload documents to the server
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

  /// Validate that required documents are selected
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

  void _showFullScreenCameraSheet({required bool isFront}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      enableDrag: false,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: KYCCameraCapture(
          onCapture: (file, {bool isAutoCapture = false}) async {
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

            if (isAutoCapture) {
              // For auto-capture, just set the file directly (no scan/crop)
              developer.log(
                'Auto capture completed for ${isFront ? 'front' : 'back'}',
              );
              if (isFront) {
                _handleFrontDocumentSelected(imageFile);
              } else {
                _handleBackDocumentSelected(imageFile);
              }
            } else {
              // For manual capture, trigger scan/crop for PASSPORT
              developer.log(
                'Manual capture completed for ${isFront ? 'front' : 'back'}',
              );
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
            }
          },
        ),
      ),
    );
  }

  /// Build document view widgets (front or back) with a single parameterized function
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

  /// Handle document selection and removal with a single parameterized function
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

  /// Check if user can proceed to next step
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

  /// Handle the continue button press
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
