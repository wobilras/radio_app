import '../models/radio_station.dart';

abstract class RadioRepository {
  Future<List<RadioStation>> getRadioStations();
  Future<void> playStation(String stationId);
  Future<void> stopStation();
}

class RadioRepositoryImpl implements RadioRepository {
  // Симуляция данных
  final List<RadioStation> _mockStations = [
    RadioStation(
      id: '1',
      name: 'Радио Маяк',
      frequency: '103.4 FM',
      description: 'Информационно-музыкальная радиостанция',
      imageUrl: 'https://via.placeholder.com/150/FF6B6B/FFFFFF?text=МАЯК',
      streamUrl: 'https://example.com/mayak',
    ),
    RadioStation(
      id: '2',
      name: 'Европа Плюс',
      frequency: '106.2 FM',
      description: 'Современная музыка и хиты',
      imageUrl: 'https://via.placeholder.com/150/4ECDC4/FFFFFF?text=ЕВРОПА+',
      streamUrl: 'https://example.com/europaplus',
    ),
    RadioStation(
      id: '3',
      name: 'Русское Радио',
      frequency: '105.7 FM',
      description: 'Лучшая русская музыка',
      imageUrl: 'https://via.placeholder.com/150/45B7D1/FFFFFF?text=РУССКОЕ',
      streamUrl: 'https://example.com/russkoe',
    ),
    RadioStation(
      id: '4',
      name: 'Ретро FM',
      frequency: '88.3 FM',
      description: 'Хиты прошлых лет',
      imageUrl: 'https://via.placeholder.com/150/F7DC6F/000000?text=РЕТРО',
      streamUrl: 'https://example.com/retro',
    ),
    RadioStation(
      id: '5',
      name: 'Rock FM',
      frequency: '95.2 FM',
      description: 'Рок музыка 24/7',
      imageUrl: 'https://via.placeholder.com/150/E74C3C/FFFFFF?text=ROCK',
      streamUrl: 'https://example.com/rock',
    ),
  ];

  @override
  Future<List<RadioStation>> getRadioStations() async {
    // Симуляция сетевого запроса
    await Future.delayed(Duration(milliseconds: 500));
    return List.from(_mockStations);
  }

  @override
  Future<void> playStation(String stationId) async {
    // Логика воспроизведения станции
    await Future.delayed(Duration(milliseconds: 300));
    print('Playing station: $stationId');
  }

  @override
  Future<void> stopStation() async {
    // Логика остановки воспроизведения
    await Future.delayed(Duration(milliseconds: 200));
    print('Stopped playing');
  }
}