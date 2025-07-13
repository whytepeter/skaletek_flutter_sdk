import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_user_info.dart';
import 'package:skaletek_kyc_flutter/src/services/kyc_service.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/content.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/button.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/file_input.dart';
import 'package:skaletek_kyc_flutter/src/ui/shared/typography.dart';

class KYCDocumentUpload extends StatefulWidget {
  const KYCDocumentUpload({
    super.key,
    this.onNext,
    required this.kycService,
    this.userInfo,
  });

  final VoidCallback? onNext;
  final KYCService kycService;
  final KYCUserInfo? userInfo;

  @override
  State<KYCDocumentUpload> createState() => _KYCDocumentUploadState();
}

class _KYCDocumentUploadState extends State<KYCDocumentUpload> {
  ImageFile? _frontDocument;
  ImageFile? _backDocument;
  PresignedUrl? _presignedUrl;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _getPresignedUrls();
    _restoreDocumentImages();
  }

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
        safePrint('Presigned url available');
        return;
      }

      final sessionToken = await widget.kycService.getSessionToken();
      if (sessionToken == null) {
        throw Exception('No session token available');
      }
      final presignedUrl = await widget.kycService.getPresignedUrls(
        sessionToken,
      );

      safePrint('Presigned url available');

      setState(() {
        _presignedUrl = presignedUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreDocumentImages() async {
    final provider = widget.kycService.stateProvider;
    if (provider?.frontDocumentPath != null && _frontDocument == null) {
      final file = File(provider!.frontDocumentPath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _frontDocument = ImageFile(
            name: file.uri.pathSegments.last,
            size: bytes.length,
            bytes: bytes,
            path: file.path,
            extension: file.uri.pathSegments.last.split('.').last,
          );
        });
      }
    }
    if (provider?.backDocumentPath != null && _backDocument == null) {
      final file = File(provider!.backDocumentPath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _backDocument = ImageFile(
            name: file.uri.pathSegments.last,
            size: bytes.length,
            bytes: bytes,
            path: file.path,
            extension: file.uri.pathSegments.last.split('.').last,
          );
        });
      }
    }
  }

  Future<void> _uploadDocuments() async {
    if (_frontDocument == null) {
      setState(() {});
      safePrint('No front document');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      if (_presignedUrl == null) {
        setState(() {});
        safePrint('No presigned url, fetching...');
        await _getPresignedUrls();
      }

      final provider = widget.kycService.stateProvider;
      final uploadTasks = <Future<void>>[];

      // Only upload front document if not already uploaded
      if (!(provider?.frontDocumentUploaded ?? false)) {
        final frontFile = File(_frontDocument!.path);
        uploadTasks.add(
          widget.kycService.uploadFrontDocument(frontFile, _presignedUrl!),
        );
      } else {
        safePrint('Front document already uploaded, skipping...');
      }

      // Only upload back document if not already uploaded
      if (_backDocument != null && !(provider?.backDocumentUploaded ?? false)) {
        final backFile = File(_backDocument!.path);
        uploadTasks.add(
          widget.kycService.uploadBackDocument(backFile, _presignedUrl!),
        );
      } else if (_backDocument != null) {
        safePrint('Back document already uploaded, skipping...');
      }

      // Only wait for uploads if there are any tasks
      if (uploadTasks.isNotEmpty) {
        await Future.wait(uploadTasks);
      }

      // Mark documents as uploaded
      await provider?.markDocumentsAsUploaded();

      // Call onNext callback
      widget.onNext?.call();
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      safePrint('Upload failed: ${e.toString()}');
    }
  }

  bool get _canProceed {
    final provider = widget.kycService.stateProvider;
    final frontUploaded = provider?.frontDocumentUploaded ?? false;
    final backUploaded = provider?.backDocumentUploaded ?? false;

    // Can proceed if front document is selected and either uploaded or ready to upload
    final frontReady =
        _frontDocument != null && (frontUploaded || !_isUploading);
    // Back document is optional, but if selected, it should be uploaded or ready
    final backReady = _backDocument == null || backUploaded || !_isUploading;

    return frontReady && backReady && !_isLoading && !_isUploading;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: KYCContent(
        step: KYCStep.document,
        userInfo: widget.userInfo,
        footer: KYCButton(
          text: _isUploading ? 'Uploading...' : 'Continue',
          block: true,
          loading: _isUploading,
          disabled: !_canProceed,
          onPressed: _canProceed ? () async => await _uploadDocuments() : () {},
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Loading state
              if (_isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                const Center(child: StyledText('Preparing upload...')),
                const SizedBox(height: 24),
              ],

              // Front document upload
              if (!_isLoading) ...[
                StyledTitle(
                  'Front view',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),
                FileInput(
                  selectedFile: _frontDocument,
                  onFileSelected: (file) {
                    setState(() {
                      _frontDocument = file;
                    });
                    widget.kycService.stateProvider?.setFrontDocumentPath(
                      file.path,
                    );
                    // Reset upload state when a new file is selected
                    widget.kycService.stateProvider?.setFrontDocumentUploaded(
                      false,
                    );
                  },
                  onFileRemoved: () {
                    setState(() {
                      _frontDocument = null;
                    });
                    widget.kycService.stateProvider?.setFrontDocumentPath(null);
                    // Reset upload state when file is removed
                    widget.kycService.stateProvider?.setFrontDocumentUploaded(
                      false,
                    );
                  },
                  disabled: _isUploading,
                ),
                const SizedBox(height: 24),

                // Back document upload (optional)
                StyledTitle(
                  'Back view ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),
                FileInput(
                  selectedFile: _backDocument,
                  onFileSelected: (file) {
                    setState(() {
                      _backDocument = file;
                    });
                    widget.kycService.stateProvider?.setBackDocumentPath(
                      file.path,
                    );
                    // Reset upload state when a new file is selected
                    widget.kycService.stateProvider?.setBackDocumentUploaded(
                      false,
                    );
                  },
                  onFileRemoved: () {
                    setState(() {
                      _backDocument = null;
                    });
                    widget.kycService.stateProvider?.setBackDocumentPath(null);
                    // Reset upload state when file is removed
                    widget.kycService.stateProvider?.setBackDocumentUploaded(
                      false,
                    );
                  },
                  disabled: _isUploading,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
