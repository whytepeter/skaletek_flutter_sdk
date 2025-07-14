// BBox type for document detection coordinates
typedef BBox = List<double>;

enum KYCStep { document, liveness }

class Fields {
  final String key;
  final String awsAccessKeyId;
  final String xAmzSecurityToken;
  final String signature;
  final String policy;

  Fields({
    required this.key,
    required this.awsAccessKeyId,
    required this.xAmzSecurityToken,
    required this.signature,
    required this.policy,
  });

  factory Fields.fromMap(Map<String, dynamic> map) {
    return Fields(
      key: map['key'] ?? '',
      awsAccessKeyId: map['AWSAccessKeyId'] ?? '',
      xAmzSecurityToken: map['x-amz-security-token'] ?? '',
      signature: map['signature'] ?? '',
      policy: map['policy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'AWSAccessKeyId': awsAccessKeyId,
      'x-amz-security-token': xAmzSecurityToken,
      'signature': signature,
      'policy': policy,
    };
  }
}

class SignedUrl {
  final String url;
  final Fields fields;

  SignedUrl({required this.url, required this.fields});

  factory SignedUrl.fromMap(Map<String, dynamic> map) {
    final url = map['url'] ?? '';
    if (url.isEmpty) {
      throw SessionError('Invalid presigned URL: URL is empty or missing');
    }

    return SignedUrl(
      url: url,
      fields: Fields.fromMap(Map<String, dynamic>.from(map['fields'] ?? {})),
    );
  }

  Map<String, dynamic> toMap() {
    return {'url': url, 'fields': fields.toMap()};
  }
}

class PresignedUrl {
  final SignedUrl front;
  final SignedUrl back;

  PresignedUrl({required this.front, required this.back});

  factory PresignedUrl.fromMap(Map<String, dynamic> map) {
    final frontMap = map['front'];
    final backMap = map['back'];

    if (frontMap == null) {
      throw SessionError(
        'Invalid presigned URL response: front URL is missing',
      );
    }
    if (backMap == null) {
      throw SessionError('Invalid presigned URL response: back URL is missing');
    }

    return PresignedUrl(
      front: SignedUrl.fromMap(Map<String, dynamic>.from(frontMap)),
      back: SignedUrl.fromMap(Map<String, dynamic>.from(backMap)),
    );
  }

  Map<String, dynamic> toMap() {
    return {'front': front.toMap(), 'back': back.toMap()};
  }
}

class GetResultParams {
  final String livenessToken;
  final String sessionToken;

  GetResultParams({required this.livenessToken, required this.sessionToken});

  Map<String, dynamic> toMap() {
    return {'liveness_token': livenessToken};
  }
}

class GetResultResponse {
  final String selfieName;
  final bool isLive;
  final String redirectUrl;
  final int remainingTries;

  GetResultResponse({
    required this.selfieName,
    required this.isLive,
    required this.redirectUrl,
    required this.remainingTries,
  });

  factory GetResultResponse.fromMap(Map<String, dynamic> map) {
    return GetResultResponse(
      selfieName: map['selfieName'] ?? '',
      isLive: map['success'] ?? false,
      redirectUrl: map['redirect_url'] ?? '',
      remainingTries: map['remaining_tries'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selfieName': selfieName,
      'isLive': isLive,
      'redirectUrl': redirectUrl,
      'remainingTries': remainingTries,
    };
  }
}

class DocumentDetectionResult {
  final bool success;
  final BBox? bbox;

  DocumentDetectionResult({required this.success, this.bbox});

  factory DocumentDetectionResult.fromMap(Map<String, dynamic> map) {
    final bboxData = map['bbox'];
    BBox? bbox;

    if (bboxData is List) {
      bbox = bboxData.map((e) => (e as num).toDouble()).toList();
    }

    return DocumentDetectionResult(
      success: map['success'] ?? false,
      bbox: bbox,
    );
  }
}

enum DetectionCheckResult { pass, fail, none }

class DetectionChecks {
  final DetectionCheckResult glare;
  final DetectionCheckResult blur;
  final DetectionCheckResult contrast;
  final DetectionCheckResult darkness;
  final DetectionCheckResult brightness;

  const DetectionChecks({
    this.glare = DetectionCheckResult.none,
    this.blur = DetectionCheckResult.none,
    this.contrast = DetectionCheckResult.none,
    this.darkness = DetectionCheckResult.none,
    this.brightness = DetectionCheckResult.none,
  });

  static const Map<String, String> labels = {
    'darkness': 'Document is fully visible',
    'brightness': 'Good lighting detected',
    'blur': 'No blur detected',
    'glare': 'No glare or reflections',
  };

  static const Map<String, String> failLabels = {
    'darkness': 'Document is not visible',
    'brightness': 'Poor lighting',
    'blur': 'Blur detected',
    'glare': 'Glare/reflections detected',
  };

  factory DetectionChecks.fromMap(Map<String, dynamic> map) {
    DetectionCheckResult parse(dynamic v) {
      if (v == 'PASS') return DetectionCheckResult.pass;
      if (v == 'FAIL') return DetectionCheckResult.fail;
      return DetectionCheckResult.none;
    }

    return DetectionChecks(
      glare: parse(map['glare']),
      blur: parse(map['blur']),
      contrast: parse(map['contrast']),
      darkness: parse(map['darkness']),
      brightness: parse(map['brightness']),
    );
  }

  Map<String, String?> toMap() => {
    'glare': _toString(glare),
    'blur': _toString(blur),
    'contrast': _toString(contrast),
    'darkness': _toString(darkness),
    'brightness': _toString(brightness),
  };

  static String? _toString(DetectionCheckResult v) {
    switch (v) {
      case DetectionCheckResult.pass:
        return 'PASS';
      case DetectionCheckResult.fail:
        return 'FAIL';
      case DetectionCheckResult.none:
      default:
        return null;
    }
  }
}

class SessionError implements Exception {
  final String message;
  final Map<String, dynamic>? data;
  final String? redirectUrl;

  SessionError(this.message, {this.data, this.redirectUrl});

  @override
  String toString() => 'SessionError: $message';
}
