import 'package:flutter/material.dart';

import '../../data/models/radio_station.dart';

class RadioStationTile extends StatelessWidget {
  final RadioStation station;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const RadioStationTile({
    super.key,
    required this.station,
    required this.isPlaying,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              container: true,
              button: true,
              label: isPlaying
                  ? 'Остановить ${station.name}'
                  : 'Воспроизвести ${station.name}',
              value: [
                if (isPlaying) 'Воспроизводится',
                if (station.country.isNotEmpty) station.country,
                station.displayInfo,
              ].join(', '),
              child: InkWell(
                borderRadius: BorderRadius.circular(16.0),
                onTap: onTap,
                child: ExcludeSemantics(child: _buildStationContent()),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: isFavorite
                    ? 'Убрать из избранного ${station.name}'
                    : 'Добавить в избранное ${station.name}',
                onPressed: onFavoriteToggle,
                isSelected: isFavorite,
                style: IconButton.styleFrom(
                  foregroundColor: isFavorite
                      ? Colors.red[700]
                      : Colors.grey[700],
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  minimumSize: const Size.square(48),
                ),
                icon: const Icon(Icons.favorite_border, size: 20),
                selectedIcon: const Icon(Icons.favorite, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16.0),
                  ),
                  color: Colors.grey[300],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16.0),
                  ),
                  child: _buildStationImage(),
                ),
              ),
              if (isPlaying)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16.0),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Icon(
                          Icons.stop,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              // Индикатор качества
              if (station.bitrate > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${station.bitrate}k',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    station.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (station.country.isNotEmpty) ...[
                      Icon(Icons.public, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          station.country,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  station.displayInfo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationImage() {
    if (station.favicon.isNotEmpty &&
        (station.favicon.startsWith('http://') ||
            station.favicon.startsWith('https://'))) {
      return Image.network(
        station.favicon,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildFallbackImage();
        },
      );
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    final colors = [
      Colors.blue[100]!,
      Colors.green[100]!,
      Colors.orange[100]!,
      Colors.purple[100]!,
      Colors.red[100]!,
      Colors.teal[100]!,
    ];

    final iconColors = [
      Colors.blue[700]!,
      Colors.green[700]!,
      Colors.orange[700]!,
      Colors.purple[700]!,
      Colors.red[700]!,
      Colors.teal[700]!,
    ];

    final colorIndex = station.name.hashCode.abs() % colors.length;

    return Container(
      color: colors[colorIndex],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radio, size: 32, color: iconColors[colorIndex]),
            if (station.name.length <= 10)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  station.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: iconColors[colorIndex],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
