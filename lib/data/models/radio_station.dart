class RadioStation {
  final String stationuuid;
  final String name;
  final String url;
  final String favicon;
  final String country;
  final String countrycode;
  final String language;
  final String tags;
  final int votes;
  final int clickcount;
  final String codec;
  final int bitrate;
  final bool isPlaying;

  RadioStation({
    required this.stationuuid,
    required this.name,
    required this.url,
    this.favicon = '',
    this.country = '',
    this.countrycode = '',
    this.language = '',
    this.tags = '',
    this.votes = 0,
    this.clickcount = 0,
    this.codec = '',
    this.bitrate = 0,
    this.isPlaying = false,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      stationuuid: json['stationuuid'] ?? '',
      name: json['name'] ?? 'Неизвестная станция',
      url: json['url_resolved'] ?? json['url'] ?? '',
      favicon: json['favicon'] ?? '',
      country: json['country'] ?? '',
      countrycode: json['countrycode'] ?? '',
      language: json['language'] ?? '',
      tags: json['tags'] ?? '',
      votes: json['votes'] ?? 0,
      clickcount: json['clickcount'] ?? 0,
      codec: json['codec'] ?? '',
      bitrate: json['bitrate'] ?? 0,
    );
  }

  Map<String, Object> toJson() => {
        'stationuuid': stationuuid,
        'name': name,
        'url': url,
        'favicon': favicon,
        'country': country,
        'countrycode': countrycode,
        'language': language,
        'tags': tags,
        'votes': votes,
        'clickcount': clickcount,
        'codec': codec,
        'bitrate': bitrate,
      };

  RadioStation copyWith({
    String? stationuuid,
    String? name,
    String? url,
    String? favicon,
    String? country,
    String? countrycode,
    String? language,
    String? tags,
    int? votes,
    int? clickcount,
    String? codec,
    int? bitrate,
    bool? isPlaying,
  }) {
    return RadioStation(
      stationuuid: stationuuid ?? this.stationuuid,
      name: name ?? this.name,
      url: url ?? this.url,
      favicon: favicon ?? this.favicon,
      country: country ?? this.country,
      countrycode: countrycode ?? this.countrycode,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      votes: votes ?? this.votes,
      clickcount: clickcount ?? this.clickcount,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  String get displayInfo {
    if (bitrate > 0) {
      return '${bitrate} kbps';
    }
    if (codec.isNotEmpty) {
      return codec.toUpperCase();
    }
    return 'RADIO';
  }
}
