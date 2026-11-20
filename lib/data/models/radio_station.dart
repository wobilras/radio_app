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
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    int number(String key) {
      final value = json[key];
      if (value is int) return value;
      return value is String ? int.tryParse(value) ?? 0 : 0;
    }

    String? streamUrl(String key) {
      final uri = Uri.tryParse(text(key));
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty)
        return null;
      return uri.toString();
    }

    final id = text('stationuuid');
    final url = streamUrl('url_resolved') ?? streamUrl('url');
    if (id.isEmpty || url == null) {
      throw const FormatException('Station is missing an ID or playable URL');
    }
    final name = text('name');
    return RadioStation(
      stationuuid: id,
      name: name.isEmpty ? 'Радиостанция' : name,
      url: url,
      favicon: text('favicon'),
      country: text('country'),
      countrycode: text('countrycode'),
      language: text('language'),
      tags: text('tags'),
      votes: number('votes'),
      clickcount: number('clickcount'),
      codec: text('codec'),
      bitrate: number('bitrate'),
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
