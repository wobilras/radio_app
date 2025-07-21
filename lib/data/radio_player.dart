import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();

  String? _currentStationId;
  String? _currentStationName;

  final StreamController<PlayerState> _stateController = StreamController<PlayerState>.broadcast();
  final StreamController<String?> _currentStationController = StreamController<String?>.broadcast();

  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<String?> get currentStationStream => _currentStationController.stream;

  String? get currentStationId => _currentStationId;
  String? get currentStationName => _currentStationName;

  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> initialize() async {
    print('Инициализация Audio Player Service...');

    _player.onPlayerStateChanged.listen((PlayerState state) {
      print('Состояние плеера изменено: $state');
      _stateController.add(state);
    });

    _player.onLog.listen((String message) {
      print('AudioPlayer Log: $message');
    });

    print('Audio Player Service инициализирован успешно');
  }

  Future<void> playStation(String stationId, String stationName, String streamUrl) async {
    try {
      print('Воспроизведение станции: $stationName ($stationId)');
      print('Stream URL: $streamUrl');
      await stop();
      await _player.play(UrlSource(streamUrl));

      _currentStationId = stationId;
      _currentStationName = stationName;
      _currentStationController.add(stationId);

      print('Станция $stationName начала воспроизводиться');
    } catch (e) {
      print('Ошибка воспроизведения станции: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      print('Остановка воспроизведения');
      await _player.stop();

      String? previousStation = _currentStationId;
      _currentStationId = null;
      _currentStationName = null;
      _currentStationController.add(null);

      if (previousStation != null) {
        print('Воспроизведение станции остановлено');
      }
    } catch (e) {
      print('Ошибка остановки воспроизведения: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      print('Воспроизведение приостановлено');
    } catch (e) {
      print('Ошибка приостановки воспроизведения: $e');
      rethrow;
    }
  }

  Future<void> resume() async {
    try {
      await _player.resume();
      print('Воспроизведение возобновлено');
    } catch (e) {
      print('Ошибка возобновления воспроизведения: $e');
      rethrow;
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      print('Громкость установлена: ${(volume * 100).round()}%');
    } catch (e) {
      print('Ошибка установки громкости: $e');
      rethrow;
    }
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
    _currentStationController.close();
    print('Audio Player Service освобожден');
  }
}