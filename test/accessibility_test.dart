import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/data/models/radio_station.dart';
import 'package:radio_app/presentation/widgets/app_bar.dart';
import 'package:radio_app/presentation/widgets/radio_station_tile.dart';
import 'package:radio_app/providers/radio_provider.dart';

void main() {
  testWidgets('Tabs expose selection and respond to the keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var selected = TabType.stations;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: MainAppBar(
              currentTab: selected,
              onTabChanged: (tab) => setState(() => selected = tab),
              searchController: controller,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('Популярные')),
      isSemantics(isButton: true, isSelected: true),
    );
    // The search field and both tabs are reached in visual order.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, TabType.favorites);
    expect(
      tester.getSemantics(find.text('Избранное')),
      isSemantics(isButton: true, isSelected: true),
    );
    semantics.dispose();
  });

  testWidgets('Station and favorite actions are exposed separately', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final station = RadioStation(
      stationuuid: 'test-id',
      name: 'Test FM',
      url: 'https://example.com/stream',
    );
    var playing = false;
    var favorite = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 224,
              child: StatefulBuilder(
                builder: (context, setState) => RadioStationTile(
                  station: station,
                  isPlaying: playing,
                  isFavorite: favorite,
                  onTap: () => setState(() => playing = !playing),
                  onFavoriteToggle: () => setState(() => favorite = !favorite),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Воспроизвести Test FM'), findsOneWidget);
    final favoriteButton = find.byTooltip('Добавить в избранное Test FM');
    expect(tester.getSize(favoriteButton), const Size(48, 48));
    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();
    expect(playing, isFalse);
    expect(favorite, isTrue);
    expect(find.byTooltip('Убрать из избранного Test FM'), findsOneWidget);

    // Traverse from the favorite button (which may retain pointer focus).
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(playing, isTrue);
    expect(find.bySemanticsLabel('Остановить Test FM'), findsOneWidget);
    semantics.dispose();
  });
}
