class KYCResult {
  final bool success;
  final String? status;
  final String? error;
  final String? errorCode;
  final Map<String, dynamic>? data;

  const KYCResult({
    required this.success,
    this.status,
    this.error,
    this.errorCode,
    this.data,
  });

  factory KYCResult.success({String? status, Map<String, dynamic>? data}) {
    return KYCResult(success: true, status: status, data: data);
  }

  factory KYCResult.failure({
    String? error,
    String? errorCode,
    Map<String, dynamic>? data,
  }) {
    return KYCResult(
      success: false,
      error: error,
      errorCode: errorCode,
      data: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (errorCode != null) 'error_code': errorCode,
      if (data != null) 'data': data,
    };
  }

  factory KYCResult.fromMap(Map<String, dynamic> map) {
    return KYCResult(
      success: map['success'] ?? false,
      status: map['status'],
      error: map['error'],
      errorCode: map['error_code'],
      data: map['data'],
    );
  }

  @override
  String toString() {
    return 'KYCResult(success: $success, status: $status, error: $error)';
  }
}
