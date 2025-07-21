class RadioStation {
  final String id;
  final String name;
  final String frequency;
  final String description;
  final String imageUrl;
  final String streamUrl;
  final String? country;
  final String? countryCode;
  final String? language;
  final String? codec;
  final int? bitrate;
  final int? votes;
  final int? clickCount;
  final String? tags;
  final bool hasGeoInfo;
  final DateTime? lastChecked;
  final bool isPlaying;

  RadioStation({
    required this.id,
    required this.name,
    required this.frequency,
    required this.description,
    required this.imageUrl,
    required this.streamUrl,
    this.country,
    this.countryCode,
    this.language,
    this.codec,
    this.bitrate,
    this.votes,
    this.clickCount,
    this.tags,
    this.hasGeoInfo = false,
    this.lastChecked,
    this.isPlaying = false,
  });

  factory RadioStation.fromRadioBrowserJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['stationuuid'] ?? '',
      name: json['name'] ?? 'Unknown Station',
      frequency: _formatFrequency(json),
      description: _formatDescription(json),
      imageUrl: _getImageUrl(json),
      streamUrl: json['url_resolved'] ?? json['url'] ?? '',
      country: json['country'],
      countryCode: json['countrycode'],
      language: json['language'],
      codec: json['codec'],
      bitrate: _parseBitrate(json['bitrate']),
      votes: _parseInt(json['votes']),
      clickCount: _parseInt(json['clickcount']),
      tags: json['tags'],
      hasGeoInfo: json['geo_lat'] != null && json['geo_long'] != null,
      lastChecked: _parseDateTime(json['lastcheckok']),
    );
  }

  static String _formatFrequency(Map<String, dynamic> json) {
    final bitrate = _parseBitrate(json['bitrate']);
    final codec = json['codec']?.toString().toUpperCase() ?? '';

    if (bitrate != null && bitrate > 0) {
      return codec.isNotEmpty ? '$codec $bitrate kbps' : '$bitrate kbps';
    }
    return 'Online Radio';
  }

  static String _formatDescription(Map<String, dynamic> json) {
    final tags = json['tags']?.toString() ?? '';
    final country = json['country']?.toString() ?? '';

    if (tags.isNotEmpty && country.isNotEmpty) {
      return '$tags • $country';
    } else if (tags.isNotEmpty) {
      return tags;
    } else if (country.isNotEmpty) {
      return country;
    }
    return 'Internet Radio';
  }

  static String _getImageUrl(Map<String, dynamic> json) {
    final favicon = json['favicon']?.toString() ?? '';
    if (favicon.isNotEmpty && Uri.tryParse(favicon) != null) {
      return favicon;
    }
    // Fallback изображение
    return 'https://via.placeholder.com/150/4ECDC4/FFFFFF?text=RADIO';
  }

  static int? _parseBitrate(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  RadioStation copyWith({
    String? id,
    String? name,
    String? frequency,
    String? description,
    String? imageUrl,
    String? streamUrl,
    String? country,
    String? countryCode,
    String? language,
    String? codec,
    int? bitrate,
    int? votes,
    int? clickCount,
    String? tags,
    bool? hasGeoInfo,
    DateTime? lastChecked,
    bool? isPlaying,
  }) {
    return RadioStation(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      language: language ?? this.language,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      votes: votes ?? this.votes,
      clickCount: clickCount ?? this.clickCount,
      tags: tags ?? this.tags,
      hasGeoInfo: hasGeoInfo ?? this.hasGeoInfo,
      lastChecked: lastChecked ?? this.lastChecked,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'description': description,
      'imageUrl': imageUrl,
      'streamUrl': streamUrl,
      'country': country,
      'countryCode': countryCode,
      'language': language,
      'codec': codec,
      'bitrate': bitrate,
      'votes': votes,
      'clickCount': clickCount,
      'tags': tags,
      'hasGeoInfo': hasGeoInfo,
      'lastChecked': lastChecked?.toIso8601String(),
    };
  }

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      frequency: json['frequency'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      streamUrl: json['streamUrl'] ?? '',
      country: json['country'],
      countryCode: json['countryCode'],
      language: json['language'],
      codec: json['codec'],
      bitrate: json['bitrate'],
      votes: json['votes'],
      clickCount: json['clickCount'],
      tags: json['tags'],
      hasGeoInfo: json['hasGeoInfo'] ?? false,
      lastChecked: json['lastChecked'] != null
          ? DateTime.parse(json['lastChecked'])
          : null,
    );
  }

  bool get isValidStream {
    return streamUrl.isNotEmpty &&
        Uri.tryParse(streamUrl) != null &&
        (streamUrl.startsWith('http://') || streamUrl.startsWith('https://'));
  }

  String get qualityRating {
    if (bitrate == null || bitrate! <= 0) return 'Unknown';
    if (bitrate! < 64) return 'Low';
    if (bitrate! < 128) return 'Medium';
    if (bitrate! < 256) return 'High';
    return 'Premium';
  }
}