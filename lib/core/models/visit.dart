class Visit {
  const Visit({
    required this.id,
    required this.propertyId,
    required this.createdAt,
    required this.createdByUserId,
    required this.workerName,
    required this.workerAvatarUrl,
    required this.note,
    required this.serviceType,
    required this.serviceChecklist,
    this.reactionCounts = const <String, int>{},
    this.userReaction,
    this.reactionDetails = const <VisitReactionDetail>[],
    required this.photos,
  });

  final String id;
  final String propertyId;
  final DateTime createdAt;
  final String createdByUserId;
  final String workerName;
  final String? workerAvatarUrl;
  final String note;
  final String serviceType;
  final List<String> serviceChecklist;
  final Map<String, int> reactionCounts;
  final String? userReaction;
  final List<VisitReactionDetail> reactionDetails;
  final List<Photo> photos;

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdByUserId: (json['createdByUserId'] as String?) ?? '',
      workerName: json['workerName'] as String,
      workerAvatarUrl: json['workerAvatarUrl'] as String?,
      note: json['note'] as String,
      serviceType: (json['serviceType'] as String?) ?? 'other',
      serviceChecklist: (json['serviceChecklist'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => '$item')
          .toList(),
      reactionCounts:
          (json['reactionCounts'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{})
              .map((key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0)),
      userReaction: (json['userReaction'] as String?)?.trim().isNotEmpty == true
          ? (json['userReaction'] as String).trim()
          : null,
      reactionDetails:
          (json['reactionDetails'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map((item) => item.map((key, value) => MapEntry('$key', value)))
              .map(VisitReactionDetail.fromJson)
              .toList(),
      photos: (json['photos'] as List<dynamic>)
          .map((item) => Photo.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'propertyId': propertyId,
      'createdAt': createdAt.toIso8601String(),
      'createdByUserId': createdByUserId,
      'workerName': workerName,
      'workerAvatarUrl': workerAvatarUrl,
      'note': note,
      'serviceType': serviceType,
      'serviceChecklist': serviceChecklist,
      'reactionCounts': reactionCounts,
      'userReaction': userReaction,
      'reactionDetails': reactionDetails.map((item) => item.toJson()).toList(),
      'photos': photos.map((photo) => photo.toJson()).toList(),
    };
  }
}

class VisitReactionDetail {
  const VisitReactionDetail({
    required this.emoji,
    required this.names,
  });

  final String emoji;
  final List<String> names;

  factory VisitReactionDetail.fromJson(Map<String, dynamic> json) {
    return VisitReactionDetail(
      emoji: (json['emoji'] as String?) ?? '',
      names: (json['names'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emoji': emoji,
      'names': names,
    };
  }
}

class Photo {
  const Photo({
    required this.url,
    this.thumbnailUrl,
    required this.createdAt,
  });

  final String url;
  final String? thumbnailUrl;
  final DateTime createdAt;

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

