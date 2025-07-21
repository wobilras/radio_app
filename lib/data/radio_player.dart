import 'dart:async';

import 'package:flutter_radio_player/data/flutter_radio_player_event.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:radio_app/data/radio_browser.dart';

import 'models/radio_station.dart';

class RadioPlayerService {
  static final FlutterRadioPlayer _radioPlayer = FlutterRadioPlayer();
  static RadioStation? _currentStation;
  static bool _isInitialized = false;
  static bool _isPlaying = false;

  static StreamSubscription<bool>? _playbackSubscription;
  static StreamSubscription<NowPlayingDataChanged?>? _nowPlayingSubscription;

  static final StreamController<bool> _playingStateController =
  StreamController<bool>.broadcast();
  static final StreamController<RadioStation?> _currentStationController =
  StreamController<RadioStation?>.broadcast();
  static final StreamController<String?> _metadataController =
  StreamController<String?>.broadcast();
  static final StreamController<AppError?> _errorController =
  StreamController<AppError?>.broadcast();

  static bool get isPlaying => _isPlaying;
  static RadioStation? get currentStation => _currentStation;
  static bool get isInitialized => _isInitialized;

  static Stream<bool> get playingStateStream => _playingStateController.stream;
  static Stream<RadioStation?> get currentStationStream => _currentStationController.stream;
  static Stream<String?> get metadataStream => _metadataController.stream;
  static Stream<AppError?> get errorStream => _errorController.stream;

  static Future<Result<void>> initialize() async {
    if (_isInitialized) {
      return Result.success(null);
    }

    try {
      _playbackSubscription = _radioPlayer.getPlaybackStream().listen(
            (isPlaying) {
          _isPlaying = isPlaying;
          _playingStateController.add(isPlaying);
        },
        onError: (error) {
          _errorController.add(AppError.player('Playback state error: $error'));
        },
      );

      _nowPlayingSubscription = _radioPlayer.getNowPlayingStream().listen(
            (nowPlayingData) {
          if (nowPlayingData != null) {
            final metadata = nowPlayingData.toString();
            _metadataController.add(metadata);
          }
        },
        onError: (error) {
          _errorController.add(AppError.player('Metadata error: $error'));
        },
      );

      _isInitialized = true;
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.player('Failed to initialize player: $e'));
    }
  }

  static Future<Result<void>> play(RadioStation station) async {
    try {
      if (!_isInitialized) {
        final initResult = await initialize();
        if (initResult.isFailure) {
          return initResult;
        }
      }

      if (_isPlaying && _currentStation?.id == station.id) {
        return Result.success(null);
      }

      if (!station.isValidStream) {
        return Result.failure(AppError.validation('Invalid stream URL'));
      }

      if (_isPlaying && _currentStation?.id != station.id) {
        await _radioPlayer.pause();
      }

      await _radioPlayer.initialize([
        {
          "title": station.name,
          "artwork": station.imageUrl,
          "url": station.streamUrl,
          "description": station.description,
        }
      ], true); // autoPlay = true

      _currentStation = station;
      _currentStationController.add(station);

      return Result.success(null);
    } catch (e) {
      _currentStation = null;
      _currentStationController.add(null);
      return Result.failure(AppError.player('Failed to play station: $e'));
    }
  }

  static Future<Result<void>> stop() async {
    try {
      if (!_isInitialized) {
        return Result.success(null);
      }

      await _radioPlayer.pause();
      _currentStation = null;
      _currentStationController.add(null);

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.player('Failed to stop playback: $e'));
    }
  }

  static Future<Result<void>> pause() async {
    try {
      if (!_isInitialized || !_isPlaying) {
        return Result.success(null);
      }

      await _radioPlayer.pause();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.player('Failed to pause playback: $e'));
    }
  }

  static Future<Result<void>> resume() async {
    try {
      if (!_isInitialized) {
        return Result.failure(AppError.player('Player not initialized'));
      }

      await _radioPlayer.play();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.player('Failed to resume playback: $e'));
    }
  }

  static Future<Result<void>> togglePlayback() async {
    if (_isPlaying) {
      return await pause();
    } else if (_currentStation != null) {
      return await resume();
    } else {
      return Result.failure(AppError.player('No station selected'));
    }
  }

  static Future<Result<Map<String, dynamic>>> getPlayerState() async {
    try {
      if (!_isInitialized) {
        return Result.failure(AppError.player('Player not initialized'));
      }

      return Result.success({
        'isPlaying': _isPlaying,
        'currentStation': _currentStation?.toJson(),
        'isInitialized': _isInitialized,
      });
    } catch (e) {
      return Result.failure(AppError.player('Failed to get player state: $e'));
    }
  }

  static Future<Result<bool>> validateStreamUrl(String url) async {
    try {
      return await RadioBrowserService.validateStreamUrl(url);
    } catch (e) {
      return Result.failure(AppError.validation('Stream validation failed: $e'));
    }
  }

  static Future<void> dispose() async {
    try {
      await _playbackSubscription?.cancel();
      await _nowPlayingSubscription?.cancel();

      await _radioPlayer.pause();

      await _playingStateController.close();
      await _currentStationController.close();
      await _metadataController.close();
      await _errorController.close();

      _isInitialized = false;
      _isPlaying = false;
      _currentStation = null;
    } catch (e) {
      print('Error disposing radio player: $e');
    }
  }

  static String getDebugInfo() {
    return '''
    Player Debug Info:
    - Initialized: $_isInitialized
    - Playing: $_isPlaying
    - Current Station: ${_currentStation?.name ?? 'None'}
    - Current URL: ${_currentStation?.streamUrl ?? 'None'}
    ''';
  }
}