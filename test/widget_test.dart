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
  @override
  Future<void> pauseStation(String stationId) async {}

  @override
  Future<void> resumeStation(String stationId) async {}
  final selected = StreamController<String?>.broadcast();
  Completer<void>? startup;
  Completer<List<RadioStation>>? catalog;
  int catalogLoads = 0;
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
    catalogLoads++;
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

class FirstReadFailsStorage extends StorageService {
  bool _fail = true;

  @override
  Future<List<RadioStation>> loadFavoriteStations() async {
    if (_fail) {
      _fail = false;
      throw StateError('Temporary read failure');
    }
    return super.loadFavoriteStations();
  }
}

void main() {
  testWidgets('Expanded player retries through its playback button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var attempts = 0;
    final repository = FakeRadioRepository()
      ..onPlay = (_) async {
        if (++attempts < 3) throw StateError('offline');
      };
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            RadioProvider(repository: repository, storage: StorageService()),
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Station One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Station One').last);
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final retry = find.descendant(
      of: sheet,
      matching: find.byTooltip('Повторить воспроизведение'),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Не удалось воспроизвести станцию.'),
      ),
      findsOneWidget,
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(attempts, 3);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Не удалось воспроизвести станцию.'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.byTooltip('Пауза')),
      findsOneWidget,
    );
  });
  testWidgets('Playback errors remain in mini player and retry succeeds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var attempts = 0;
    final repository = FakeRadioRepository()
      ..onPlay = (_) async {
        if (++attempts == 1) throw StateError('offline');
      };
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            RadioProvider(repository: repository, storage: StorageService()),
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Station One'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось воспроизвести станцию.'), findsOneWidget);
    expect(find.byTooltip('Повторить воспроизведение'), findsOneWidget);
    await tester.tap(find.byTooltip('Повторить воспроизведение'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Не удалось воспроизвести станцию.'), findsNothing);
    expect(find.byTooltip('Пауза'), findsOneWidget);
  });
  testWidgets('Mini player pauses and opens the station sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = FakeRadioRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            RadioProvider(repository: repository, storage: StorageService()),
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Пауза'), findsNothing);
    await tester.tap(find.text('Station One'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Пауза'), findsOneWidget);
    await tester.tap(find.byTooltip('Пауза'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Продолжить'), findsOneWidget);
    await tester.tap(find.text('Station One').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Закрыть'), findsOneWidget);
    await tester.tap(find.byTooltip('Продолжить').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Пауза'), findsWidgets);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(repository.currentStationId, 'one');
  });
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

      expect(find.text('Station Two'), findsNWidgets(2));
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

  testWidgets(
    'Favorites stay visible while catalog loads and stale search completes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = FakeRadioRepository()
        ..catalog = Completer<List<RadioStation>>();
      final firstSearch = Completer<List<RadioStation>>();
      repository.onSearch = (_) => firstSearch.future;
      final storage = StorageService();
      await storage.toggleFavorite(repository.stations.last);
      final provider = RadioProvider(repository: repository, storage: storage);
      addTearDown(provider.dispose);
      await tester.pump();
      expect(repository.catalogLoads, 1);

      provider.searchController.text = 'a';
      await tester.pump(const Duration(milliseconds: 500));
      provider.setCurrentTab(TabType.favorites);
      firstSearch.complete([repository.stations.first]);
      await tester.pump();
      expect(provider.isLoading, isFalse);
      expect(provider.searchQuery, isEmpty);
      expect(provider.filteredStations.single.stationuuid, 'two');
      await provider.reloadActive();
      expect(repository.catalogLoads, 1);

      provider.setCurrentTab(TabType.stations);
      final retry = provider.loadStations();
      expect(repository.catalogLoads, 1);
      repository.catalog!.complete(repository.stations);
      await retry;
      expect(provider.filteredStations, hasLength(2));
    },
  );

  testWidgets(
    'Recovery actions stay reachable with large text and a keyboard',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      var fails = true;
      final repository = FakeRadioRepository()
        ..onSearch = (_) async {
          if (fails) throw StateError('offline');
          return [];
        };
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) =>
              RadioProvider(repository: repository, storage: StorageService()),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const MainScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'jazz');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final retry = find.widgetWithText(TextButton, 'Повторить');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      expect(retry.hitTestable(), findsOneWidget);
      fails = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      final refresh = find.widgetWithText(OutlinedButton, 'Обновить серверы');
      await tester.ensureVisible(refresh);
      await tester.pumpAndSettle();
      expect(refresh.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Adding a favorite after a failed read preserves stored cards', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = FakeRadioRepository()
      ..catalog = Completer<List<RadioStation>>();
    await StorageService().toggleFavorite(repository.stations.first);
    final storage = FirstReadFailsStorage();
    final provider = RadioProvider(repository: repository, storage: storage);
    addTearDown(provider.dispose);
    await tester.pump();
    expect(provider.favoriteStations, isEmpty);
    await provider.toggleFavorite(repository.stations.last);
    final reloaded = await StorageService().loadFavoriteStations();
    expect(reloaded.map((station) => station.stationuuid), ['one', 'two']);
    repository.catalog!.complete(repository.stations);
    await tester.pump();
  });
}
