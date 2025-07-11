class RadioStation {
  final String id;
  final String name;
  final String frequency;
  final String description;
  final String imageUrl;
  final String streamUrl;
  final bool isPlaying;

  RadioStation({
    required this.id,
    required this.name,
    required this.frequency,
    required this.description,
    required this.imageUrl,
    required this.streamUrl,
    this.isPlaying = false,
  });

  RadioStation copyWith({
    String? id,
    String? name,
    String? frequency,
    String? description,
    String? imageUrl,
    String? streamUrl,
    bool? isPlaying,
  }) {
    return RadioStation(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}