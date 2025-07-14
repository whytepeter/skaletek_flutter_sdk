/// KYCStatus enum for KYC flow status values.
enum KYCStatus {
  failure('FAILURE'),
  success('SUCCESS'),
  inProgress('IN_PROGRESS'),
  pending('PENDING'),
  completed('COMPLETED'),
  reject('REJECT'),
  cancelled('CANCELLED');

  const KYCStatus(this.value);
  final String value;
}

/// KYCResult model for KYC flow results.
class KYCResult {
  final bool success;
  final KYCStatus? status;

  const KYCResult({required this.success, this.status});

  factory KYCResult.success({KYCStatus? status}) {
    return KYCResult(success: true, status: status ?? KYCStatus.success);
  }

  factory KYCResult.failure({KYCStatus? status}) {
    return KYCResult(success: false, status: status ?? KYCStatus.failure);
  }

  Map<String, dynamic> toMap() {
    return {'success': success, if (status != null) 'status': status!.value};
  }

  factory KYCResult.fromMap(Map<String, dynamic> map) {
    final statusValue = map['status'] as String?;
    KYCStatus? status;
    if (statusValue != null) {
      status = KYCStatus.values.firstWhere(
        (s) => s.value == statusValue,
        orElse: () => KYCStatus.failure,
      );
    }
    return KYCResult(success: map['success'] ?? false, status: status);
  }

  @override
  String toString() {
    return 'KYCResult(success: $success, status: ${status?.value})';
  }
}
