import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/radio_station.dart';
import '../../providers/radio_provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RadioProvider>(
      builder: (context, radio, _) {
        final station = radio.currentStation;
        if (station == null) return const SizedBox.shrink();
        final wide = MediaQuery.sizeOf(context).width >= 600;
        return SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 16 : 0,
                  0,
                  wide ? 16 : 0,
                  wide ? 12 : 0,
                ),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openPlayer(context),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                StationArtwork(station: station, size: 48),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        station.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (radio.playbackFailure != null)
                                        Text(
                                          radio.playbackFailure!.message,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: radio.isFavorite(station.stationuuid)
                            ? 'Убрать из избранного ${station.name}'
                            : 'Добавить в избранное ${station.name}',
                        onPressed: () => radio.toggleFavorite(station),
                        isSelected: radio.isFavorite(station.stationuuid),
                        icon: const Icon(Icons.favorite_border),
                        selectedIcon: Icon(
                          Icons.favorite,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(width: 24),
                      _PlaybackButton(radio: radio),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPlayer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const _PlayerSheet(),
    );
  }
}

class StationArtwork extends StatelessWidget {
  const StationArtwork({super.key, required this.station, required this.size});

  final RadioStation station;
  final double size;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(station.favicon);
    final valid =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    final fallback = Container(
      color: Colors.blue.shade100,
      child: Icon(Icons.radio, color: Colors.blue.shade700, size: size * 0.4),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: valid
            ? Image.network(
                station.favicon,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              )
            : fallback,
      ),
    );
  }
}

class _PlaybackButton extends StatelessWidget {
  const _PlaybackButton({required this.radio});

  final RadioProvider radio;

  @override
  Widget build(BuildContext context) {
    final failure = radio.playbackFailure;
    return IconButton(
      onPressed: radio.playbackBusy
          ? null
          : (failure?.retry ?? radio.togglePlayback),
      tooltip: failure != null
          ? 'Повторить воспроизведение'
          : (radio.isPaused ? 'Продолжить' : 'Пауза'),
      icon: Icon(
        failure != null
            ? Icons.refresh
            : (radio.isPaused ? Icons.play_arrow : Icons.pause),
      ),
      iconSize: 30,
    );
  }
}

class _PlayerSheet extends StatelessWidget {
  const _PlayerSheet();

  @override
  Widget build(BuildContext context) {
    final radio = context.watch<RadioProvider>();
    final station = radio.currentStation;
    if (station == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Воспроизведение остановлено'),
        ),
      );
    }
    final media = MediaQuery.of(context);
    final wide = media.size.width >= 600;
    final height = wide
        ? (media.size.height * 0.8).clamp(0.0, 560.0)
        : media.size.height - media.padding.top;
    return SizedBox(
      height: height,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              const SizedBox(height: 20),
              StationArtwork(
                station: station,
                size: (media.size.width * 0.7).clamp(0.0, 280.0),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  station.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              if (radio.playbackFailure != null) ...[
                Text(radio.playbackFailure!.message),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: radio.isFavorite(station.stationuuid)
                        ? 'Убрать из избранного ${station.name}'
                        : 'Добавить в избранное ${station.name}',
                    onPressed: () => radio.toggleFavorite(station),
                    isSelected: radio.isFavorite(station.stationuuid),
                    icon: const Icon(Icons.favorite_border),
                    selectedIcon: Icon(Icons.favorite, color: Colors.red[700]),
                  ),
                  const SizedBox(width: 24),
                  _PlaybackButton(radio: radio),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
