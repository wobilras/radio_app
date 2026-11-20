import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:radio_app/data/models/radio_station.dart';
import 'package:radio_app/data/repositories/radio_repository.dart';
import 'package:radio_app/data/storage.dart';
import 'package:radio_app/presentation/screens/main_screen.dart';
import 'package:radio_app/presentation/widgets/radio_station_tile.dart';
import 'package:radio_app/providers/radio_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRadioRepository implements RadioRepository {
  final selected = StreamController<String?>.broadcast();
  Completer<void>? startup;
  Completer<List<RadioStation>>? catalog;
  Future<List<RadioStation>> Function(String)? onSearch;
  Future<void> Function(RadioStation)? onPlay;
  final stations = [
    RadioStation(
      stationuuid: 'one',
      name: 'Station One',
      url: 'https://example.test/one',
    ),
    RadioStation(
      stationuuid: 'two',
      name: 'Station Two',
      url: 'https://example.test/two',
    ),
  ];
  String? _currentStationId;

  @override
  String? get currentStationId => _currentStationId;

  @override
  Stream<String?> get currentStationStream => selected.stream;

  @override
  Future<void> initialize() async => startup?.future;

  @override
  Future<List<RadioStation>> getRadioStations() async {
    final pending = catalog;
    return pending == null ? stations : await pending.future;
  }

  @override
  Future<List<RadioStation>> searchStations(String query) async {
    final search = onSearch;
    if (search != null) return search(query);
    return stations.where((station) => station.name.contains(query)).toList();
  }

  @override
  Future<List<RadioStation>> getStationsByCountry(String countryCode) async =>
      [];

  @override
  Future<void> refreshServers() async {}

  @override
  Future<void> playStation(RadioStation station) async {
    await onPlay?.call(station);
    _currentStationId = station.stationuuid;
    selected.add(_currentStationId);
  }

  @override
  Future<void> stopStation() async {
    _currentStationId = null;
    selected.add(null);
  }

  @override
  void dispose() => unawaited(selected.close());
}

void main() {
  testWidgets('Does not publish or attach listeners after disposal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = FakeRadioRepository()..startup = Completer<void>();
    final provider = RadioProvider(
      repository: repository,
      storage: StorageService(),
    );
    provider.dispose();
    repository.startup!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final loadingRepository = FakeRadioRepository()
      ..catalog = Completer<List<RadioStation>>();
    final loadingProvider = RadioProvider(
      repository: loadingRepository,
      storage: StorageService(),
    );
    await tester.pump();
    expect(loadingProvider.isLoading, isTrue);
    loadingProvider.dispose();
    loadingRepository.catalog!.complete(loadingRepository.stations);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Loads stations, plays the selected station and saves a favorite',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = FakeRadioRepository();
      final storage = StorageService();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) =>
              RadioProvider(repository: repository, storage: storage),
          child: const MaterialApp(home: MainScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Station One'), findsOneWidget);
      expect(find.text('Station Two'), findsOneWidget);
      await tester.tap(find.text('Station Two'));
      await tester.pumpAndSettle();
      expect(repository.currentStationId, 'two');
      expect(
        tester
            .widget<RadioStationTile>(find.byType(RadioStationTile).last)
            .isPlaying,
        isTrue,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(RadioStationTile).last,
          matching: find.byIcon(Icons.favorite_border),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Избранное'));
      await tester.pumpAndSettle();

      expect(find.text('Station Two'), findsOneWidget);
      expect(find.text('Station One'), findsNothing);
      expect((await storage.loadFavoriteStations()).single.stationuuid, 'two');
    },
  );

  testWidgets(
    'Search ignores caret changes and results from an earlier identical query',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final requests = <Completer<List<RadioStation>>>[];
      final repository = FakeRadioRepository()
        ..onSearch = (_) {
          final pending = Completer<List<RadioStation>>();
          requests.add(pending);
          return pending.future;
        };
      final provider = RadioProvider(
        repository: repository,
        storage: StorageService(),
      );
      addTearDown(provider.dispose);
      final input = provider.searchController;
      input.text = 'a';
      input.selection = const TextSelection.collapsed(offset: 1);
      input.text = 'a ';
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests, hasLength(1));
      input.text = 'b';
      await tester.pump(const Duration(milliseconds: 500));
      input.text = 'a';
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests, hasLength(3));

      requests[2].complete([repository.stations.last]);
      await tester.pump();
      requests[0].complete([repository.stations.first]);
      requests[1].complete([]);
      await tester.pump();
      expect(provider.searchResults.single.stationuuid, 'two');
      expect(provider.isSearching, isFalse);
      provider.clearSearch();
      expect(provider.searchResults, isEmpty);
    },
  );

  testWidgets('Retry uses the failed play or search operation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final plays = <String>[];
    final searches = <String>[];
    final repository = FakeRadioRepository()
      ..onPlay = (station) async {
        plays.add(station.stationuuid);
        if (plays.length == 1) throw StateError('offline');
      }
      ..onSearch = (query) async {
        searches.add(query);
        if (searches.length == 1) throw StateError('offline');
        return [];
      };
    final provider = RadioProvider(
      repository: repository,
      storage: StorageService(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => provider,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await provider.playStation(repository.stations.first);
    await tester.pump();
    expect(find.text('Station Two'), findsOneWidget);
    await provider.playbackFailure!.retry();
    await tester.pump();
    expect(plays, ['one', 'one']);
    expect(provider.playbackFailure, isNull);

    provider.searchController.text = 'jazz';
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(provider.catalogError, isNotNull);
    await provider.reloadActive();
    await tester.pump();
    expect(provider.catalogError, isNull);
    expect(provider.searchResults, isEmpty);
    expect(searches, ['jazz', 'jazz']);
  });
}
