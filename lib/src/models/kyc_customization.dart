class KYCCustomization {
  final String docSrc;
  final String? logoUrl;
  final String? logoWidth;
  final String? logoHeight;
  final String? partnerName;
  final String? partnerPhone;
  final String? partnerEmail;
  final String? helpUrl;
  final String? primaryColor;

  const KYCCustomization({
    required this.docSrc,
    this.logoUrl,
    this.logoWidth,
    this.logoHeight,
    this.partnerName,
    this.partnerPhone,
    this.partnerEmail,
    this.helpUrl,
    this.primaryColor,
  });

  Map<String, String> toMap() {
    final map = <String, String>{'doc_src': docSrc};

    if (logoUrl != null) map['logo_url'] = logoUrl!;
    if (logoWidth != null) map['logo_width'] = logoWidth!;
    if (logoHeight != null) map['logo_height'] = logoHeight!;
    if (partnerName != null) map['partner_name'] = partnerName!;
    if (partnerPhone != null) map['partner_phone'] = partnerPhone!;
    if (partnerEmail != null) map['partner_email'] = partnerEmail!;
    if (helpUrl != null) map['help_url'] = helpUrl!;
    if (primaryColor != null) map['primary_color'] = primaryColor!;

    return map;
  }

  factory KYCCustomization.fromMap(Map<String, dynamic> map) {
    return KYCCustomization(
      docSrc: map['doc_src'] ?? 'LIVE',
      logoUrl: map['logo_url'],
      logoWidth: map['logo_width'],
      logoHeight: map['logo_height'],
      partnerName: map['partner_name'],
      partnerPhone: map['partner_phone'],
      partnerEmail: map['partner_email'],
      helpUrl: map['help_url'],
      primaryColor: map['primary_color'],
    );
  }

  @override
  String toString() {
    return 'KYCCustomization(docSrc: $docSrc, logoUrl: $logoUrl, partnerName: $partnerName, primaryColor: $primaryColor)';
  }
}

enum DocumentSource {
  live('LIVE'),
  file('FILE');

  const DocumentSource(this.value);
  final String value;
}
