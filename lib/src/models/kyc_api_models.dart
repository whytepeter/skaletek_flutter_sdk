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

class SessionError implements Exception {
  final String message;
  final Map<String, dynamic>? data;
  final String? redirectUrl;

  SessionError(this.message, {this.data, this.redirectUrl});

  @override
  String toString() => 'SessionError: $message';
}
