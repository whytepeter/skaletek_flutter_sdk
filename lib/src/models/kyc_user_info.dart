class KYCUserInfo {
  final String firstName;
  final String lastName;
  final String documentType;
  final String issuingCountry;

  const KYCUserInfo({
    required this.firstName,
    required this.lastName,
    required this.documentType,
    required this.issuingCountry,
  });

  Map<String, String> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'document_type': documentType,
      'issuing_country': issuingCountry,
    };
  }

  factory KYCUserInfo.fromMap(Map<String, dynamic> map) {
    return KYCUserInfo(
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      documentType: map['document_type'] ?? '',
      issuingCountry: map['issuing_country'] ?? '',
    );
  }

  @override
  String toString() {
    return 'KYCUserInfo(firstName: $firstName, lastName: $lastName, documentType: $documentType, issuingCountry: $issuingCountry)';
  }
}

enum DocumentType {
  passport('PASSPORT'),
  nationalId('NATIONAL_ID'),
  residencePermit('RESIDENCE_PERMIT'),
  healthCard('HEALTH_CARD'),
  driverLicense('DRIVER_LICENCE');

  const DocumentType(this.value);
  final String value;
}
