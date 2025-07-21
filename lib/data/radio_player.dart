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
  static bool _pluginAvailable = false;

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
  static bool get pluginAvailable => _pluginAvailable;

  static Stream<bool> get playingStateStream => _playingStateController.stream;
  static Stream<RadioStation?> get currentStationStream => _currentStationController.stream;
  static Stream<String?> get metadataStream => _metadataController.stream;
  static Stream<AppError?> get errorStream => _errorController.stream;

  static Future<Result<void>> initialize() async {
    if (_isInitialized) {
      return Result.success(null);
    }

    print('Initializing Radio Player Service...');

    try {
      try {
        _playbackSubscription = _radioPlayer.getPlaybackStream().listen(
              (isPlaying) {
            _isPlaying = isPlaying;
            _playingStateController.add(isPlaying);
            if (!_pluginAvailable) {
              print('Plugin became available!');
              _pluginAvailable = true;
            }
          },
          onError: (error) {
            print('Playback stream error: $error');
            _pluginAvailable = false;
            _errorController.add(AppError.player('Playback state error: $error'));
          },
        );

        print('Successfully subscribed to playback stream');
        _pluginAvailable = true;
      } catch (e) {
        print('Failed to subscribe to playback stream: $e');
        _pluginAvailable = false;
      }

      try {
        _nowPlayingSubscription = _radioPlayer.getNowPlayingStream().listen(
              (nowPlayingData) {
            if (nowPlayingData != null) {
              final metadata = nowPlayingData.toString();
              _metadataController.add(metadata);
            }
          },
          onError: (error) {
            print('Now playing stream error: $error');
          },
        );
        print('Successfully subscribed to now playing stream');
      } catch (e) {
        print('Failed to subscribe to now playing stream: $e');
      }

      _isInitialized = true;
      print('Radio Player Service initialized - Plugin available: $_pluginAvailable');
      return Result.success(null);
    } catch (e) {
      print('Failed to initialize player: $e');
      _pluginAvailable = false;
      _isInitialized = true;
      print('Running in fallback mode');
      return Result.success(null);
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

      if (!_pluginAvailable) {
        print('Plugin not available, simulating playback for: ${station.name}');
        _currentStation = station;
        _isPlaying = true;
        _currentStationController.add(station);
        _playingStateController.add(true);
        return Result.success(null);
      }

      if (_isPlaying && _currentStation?.id == station.id) {
        return Result.success(null);
      }

      // Валидируем URL перед воспроизведением
      if (!station.isValidStream) {
        return Result.failure(AppError.validation('Invalid stream URL'));
      }

      // Останавливаем текущее воспроизведение если играет другая станция
      if (_isPlaying && _currentStation?.id != station.id) {
        try {
          await _radioPlayer.pause();
        } catch (e) {
          print('Failed to pause previous station: $e');
        }
      }

      // Инициализируем плеер с новой станцией
      try {
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
        print('Failed to initialize radio player: $e');
        // Fallback к эмуляции
        _pluginAvailable = false;
        _currentStation = station;
        _isPlaying = true;
        _currentStationController.add(station);
        _playingStateController.add(true);
        return Result.success(null);
      }
    } catch (e) {
      _currentStation = null;
      _currentStationController.add(null);
      return Result.failure(AppError.player('Failed to play station: $e'));
    }
  }

  // Остановка воспроизведения
  static Future<Result<void>> stop() async {
    try {
      if (!_isInitialized) {
        return Result.success(null);
      }

      if (_pluginAvailable) {
        try {
          await _radioPlayer.pause();
        } catch (e) {
          print('Failed to pause radio player: $e');
          // Продолжаем работу в fallback режиме
        }
      }

      _currentStation = null;
      _isPlaying = false;
      _currentStationController.add(null);
      _playingStateController.add(false);

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.player('Failed to stop playback: $e'));
    }
  }

  // Пауза
  static Future<Result<void>> pause() async {
    try {
      if (!_isInitialized || !_isPlaying) {
        return Result.success(null);
      }

      if (_pluginAvailable) {
        try {
          await _radioPlayer.pause();
        } catch (e) {
          print('Failed to pause: $e');
          // Fallback
          _isPlaying = false;
          _playingStateController.add(false);
        }
      } else {
        _isPlaying = false;
        _playingStateController.add(false);
      }

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.player('Failed to pause playback: $e'));
    }
  }

  // Возобновление воспроизведения
  static Future<Result<void>> resume() async {
    try {
      if (!_isInitialized) {
        return Result.failure(AppError.player('Player not initialized'));
      }

      if (_pluginAvailable) {
        try {
          await _radioPlayer.play();
        } catch (e) {
          print('Failed to resume: $e');
          // Fallback
          _isPlaying = true;
          _playingStateController.add(true);
        }
      } else {
        _isPlaying = true;
        _playingStateController.add(true);
      }

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.player('Failed to resume playback: $e'));
    }
  }

  // Переключение воспроизведения
  static Future<Result<void>> togglePlayback() async {
    if (_isPlaying) {
      return await pause();
    } else if (_currentStation != null) {
      return await resume();
    } else {
      return Result.failure(AppError.player('No station selected'));
    }
  }

  // Проверка состояния плеера
  static Future<Result<Map<String, dynamic>>> getPlayerState() async {
    try {
      return Result.success({
        'isPlaying': _isPlaying,
        'currentStation': _currentStation?.toJson(),
        'isInitialized': _isInitialized,
        'pluginAvailable': _pluginAvailable,
      });
    } catch (e) {
      return Result.failure(AppError.player('Failed to get player state: $e'));
    }
  }

  // Валидация URL потока перед воспроизведением
  static Future<Result<bool>> validateStreamUrl(String url) async {
    try {
      // Используем сервис из RadioBrowserService
      return await RadioBrowserService.validateStreamUrl(url);
    } catch (e) {
      return Result.failure(AppError.validation('Stream validation failed: $e'));
    }
  }

  // Освобождение ресурсов
  static Future<void> dispose() async {
    try {
      await _playbackSubscription?.cancel();
      await _nowPlayingSubscription?.cancel();

      if (_pluginAvailable) {
        try {
          await _radioPlayer.pause();
        } catch (e) {
          print('Error during player dispose: $e');
        }
      }

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

  // Методы для отладки
  static String getDebugInfo() {
    return '''
    Player Debug Info:
    - Initialized: $_isInitialized
    - Playing: $_isPlaying
    - Plugin Available: $_pluginAvailable
    - Current Station: ${_currentStation?.name ?? 'None'}
    - Current URL: ${_currentStation?.streamUrl ?? 'None'}
    ''';
  }
}