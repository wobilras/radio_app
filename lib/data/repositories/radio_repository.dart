import '../models/radio_station.dart';
import '../radio_browser.dart';
import '../radio_player.dart';
import '../storage.dart';

abstract class RadioRepository {
  Future<Result<List<RadioStation>>> getPopularStations({int limit = 50, int offset = 0});
  Future<Result<List<RadioStation>>> getTopVotedStations({int limit = 50, int offset = 0});
  Future<Result<List<RadioStation>>> searchStations({
    String? name,
    String? country,
    String? tag,
    int limit = 30,
  });
  Future<Result<List<RadioStation>>> getStationsByCountry(String countryCode);
  Future<Result<List<RadioStation>>> getStationsByTag(String tag);
  Future<Result<List<RadioStation>>> getNewStations({int limit = 50});
  Future<Result<void>> playStation(RadioStation station);
  Future<Result<void>> stopStation();
  Future<Result<void>> pauseStation();
  Future<Result<void>> resumeStation();
  Future<Result<void>> saveFavoriteStations(List<String> favoriteIds);
  Future<Result<List<String>>> loadFavoriteStations();
  Future<Result<bool>> validateStreamUrl(String url);
  Future<Result<void>> incrementStationClick(String stationId);
}

class RadioRepositoryImpl implements RadioRepository {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  @override
  Future<Result<List<RadioStation>>> getPopularStations({
    int limit = 50,
    int offset = 0,
  }) async {
    return await _executeWithRetry(() async {
      return await RadioBrowserService.getTopClickStations(
        limit: limit,
        offset: offset,
      );
    });
  }

  @override
  Future<Result<List<RadioStation>>> getTopVotedStations({
    int limit = 50,
    int offset = 0,
  }) async {
    return await _executeWithRetry(() async {
      return await RadioBrowserService.getTopVotedStations(
        limit: limit,
        offset: offset,
      );
    });
  }

  @override
  Future<Result<List<RadioStation>>> searchStations({
    String? name,
    String? country,
    String? tag,
    int limit = 30,
  }) async {
    try {
      if (name?.trim().isEmpty == true &&
          country?.trim().isEmpty == true &&
          tag?.trim().isEmpty == true) {
        return await getPopularStations(limit: limit);
      }

      return await _executeWithRetry(() async {
        return await RadioBrowserService.searchStations(
          name: name?.trim(),
          country: country?.trim(),
          tag: tag?.trim(),
          limit: limit,
        );
      });
    } catch (e) {
      return Result.failure(AppError.network('Search failed: $e'));
    }
  }

  @override
  Future<Result<List<RadioStation>>> getStationsByCountry(String countryCode) async {
    return await _executeWithRetry(() async {
      return await RadioBrowserService.getStationsByCountry(countryCode);
    });
  }

  @override
  Future<Result<List<RadioStation>>> getStationsByTag(String tag) async {
    return await _executeWithRetry(() async {
      return await RadioBrowserService.getStationsByTag(tag);
    });
  }

  @override
  Future<Result<List<RadioStation>>> getNewStations({int limit = 50}) async {
    return await _executeWithRetry(() async {
      return await RadioBrowserService.getNewStations(limit: limit);
    });
  }

  @override
  Future<Result<void>> playStation(RadioStation station) async {
    try {
      final validationResult = await validateStreamUrl(station.streamUrl);
      if (validationResult.isFailure) {
        return Result.failure(AppError.validation('Invalid stream URL'));
      }

      if (validationResult.data == false) {
        return Result.failure(AppError.validation('Stream is not accessible'));
      }

      final playResult = await RadioPlayerService.play(station);

      if (playResult.isSuccess) {
        incrementStationClick(station.id).then((result) {
          if (result.isFailure) {
            print('Failed to increment click count: ${result.error}');
          }
        });
      }

      return playResult;
    } catch (e) {
      return Result.failure(AppError.player('Failed to play station: $e'));
    }
  }

  @override
  Future<Result<void>> stopStation() async {
    try {
      return await RadioPlayerService.stop();
    } catch (e) {
      return Result.failure(AppError.player('Failed to stop station: $e'));
    }
  }

  @override
  Future<Result<void>> pauseStation() async {
    try {
      return await RadioPlayerService.pause();
    } catch (e) {
      return Result.failure(AppError.player('Failed to pause station: $e'));
    }
  }

  @override
  Future<Result<void>> resumeStation() async {
    try {
      return await RadioPlayerService.resume();
    } catch (e) {
      return Result.failure(AppError.player('Failed to resume station: $e'));
    }
  }

  @override
  Future<Result<void>> saveFavoriteStations(List<String> favoriteIds) async {
    try {
      await StorageService.saveFavoriteStations(favoriteIds);
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.storage('Failed to save favorites: $e'));
    }
  }

  @override
  Future<Result<List<String>>> loadFavoriteStations() async {
    try {
      final favorites = await StorageService.loadFavoriteStations();
      return Result.success(favorites);
    } catch (e) {
      return Result.failure(AppError.storage('Failed to load favorites: $e'));
    }
  }

  @override
  Future<Result<bool>> validateStreamUrl(String url) async {
    try {
      return await RadioBrowserService.validateStreamUrl(url);
    } catch (e) {
      return Result.failure(AppError.validation('URL validation failed: $e'));
    }
  }

  @override
  Future<Result<void>> incrementStationClick(String stationId) async {
    try {
      return await RadioBrowserService.incrementClickCount(stationId);
    } catch (e) {
      return Result.failure(AppError.network('Failed to increment click count: $e'));
    }
  }

  Future<Result<T>> _executeWithRetry<T>(
      Future<Result<T>> Function() operation,
      ) async {
    AppError? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final result = await operation();

        if (result.isSuccess) {
          return result;
        } else {
          lastError = result.error!;

          if (attempt == _maxRetries) {
            break;
          }

          await Future.delayed(_retryDelay * attempt);
        }
      } catch (e) {
        lastError = AppError.network('Attempt $attempt failed: $e');

        if (attempt == _maxRetries) {
          break;
        }

        await Future.delayed(_retryDelay * attempt);
      }
    }

    return Result.failure(lastError ?? AppError.network('Unknown error'));
  }

  // Получить моковые данные для fallback
  Future<Result<List<RadioStation>>> _getFallbackStations() async {
    try {
      final fallbackStations = [
        RadioStation(
          id: 'fallback_1',
          name: 'Classic FM',
          frequency: '128 kbps',
          description: 'Classical Music • United Kingdom',
          imageUrl: 'https://via.placeholder.com/150/FF6B6B/FFFFFF?text=CLASSIC',
          streamUrl: 'http://media-ice.musicradio.com/ClassicFMMP3',
          country: 'United Kingdom',
          countryCode: 'GB',
          language: 'english',
          codec: 'MP3',
          bitrate: 128,
        ),
        RadioStation(
          id: 'fallback_2',
          name: 'Jazz Radio',
          frequency: '320 kbps',
          description: 'Jazz Music • France',
          imageUrl: 'https://via.placeholder.com/150/4ECDC4/FFFFFF?text=JAZZ',
          streamUrl: 'http://jazz-wr04.ice.infomaniak.ch/jazz-wr04-128.mp3',
          country: 'France',
          countryCode: 'FR',
          language: 'french',
          codec: 'MP3',
          bitrate: 320,
        ),
        RadioStation(
          id: 'fallback_3',
          name: 'BBC Radio 1',
          frequency: '128 kbps',
          description: 'Pop Music • United Kingdom',
          imageUrl: 'https://via.placeholder.com/150/45B7D1/FFFFFF?text=BBC',
          streamUrl: 'http://stream.live.vc.bbcmedia.co.uk/bbc_radio_one',
          country: 'United Kingdom',
          countryCode: 'GB',
          language: 'english',
          codec: 'MP3',
          bitrate: 128,
        ),
      ];

      return Result.success(fallbackStations);
    } catch (e) {
      return Result.failure(AppError.network('Failed to load fallback stations: $e'));
    }
  }
}