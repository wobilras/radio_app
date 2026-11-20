import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/radio_provider.dart';
import '../widgets/app_bar.dart';
import '../widgets/radio_station_tile.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360 && MediaQuery.textScalerOf(context).scale(16) > 24) {
      return 1;
    }
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RadioProvider>();
    final currentTab = context.select(
      (RadioProvider provider) => provider.currentTab,
    );
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          160 +
              (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 24) *
                  3.5,
        ),
        child: MainAppBar(
          currentTab: currentTab,
          onTabChanged: provider.setCurrentTab,
          searchController: provider.searchController,
          onSearchClear: provider.clearSearch,
        ),
      ),
      body: Consumer<RadioProvider>(
        builder: (context, provider, _) => _buildContent(context, provider),
      ),
    );
  }

  Widget _buildContent(BuildContext context, RadioProvider provider) {
    final stations = provider.filteredStations;
    final catalogError = provider.catalogError;
    final favoritesError = provider.favoritesError;
    final playback = provider.playbackFailure;
    final loading = provider.isLoading || provider.isSearching;
    return RefreshIndicator(
      onRefresh: provider.reloadActive,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (catalogError != null || provider.hasFallbackStations)
            SliverToBoxAdapter(
              child: _StatusMessage(
                message: catalogError ?? 'Показаны резервные станции.',
                onRetry: provider.reloadActive,
              ),
            ),
          if (favoritesError != null)
            SliverToBoxAdapter(child: _StatusMessage(message: favoritesError)),
          if (playback != null)
            SliverToBoxAdapter(
              child: _StatusMessage(
                message: playback.message,
                onRetry: playback.retry,
              ),
            ),
          if (loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        provider.isSearching
                            ? 'Поиск станций...'
                            : 'Загрузка популярных станций...',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (stations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyStations(provider: provider),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: stations.length,
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return RadioStationTile(
                    key: ValueKey(station.stationuuid),
                    station: station,
                    isPlaying: provider.currentPlayingId == station.stationuuid,
                    isFavorite: provider.isFavorite(station.stationuuid),
                    onTap: () => provider.playStation(station),
                    onFavoriteToggle: () => provider.toggleFavorite(station),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyStations extends StatelessWidget {
  const _EmptyStations({required this.provider});

  final RadioProvider provider;

  @override
  Widget build(BuildContext context) {
    final query = provider.searchQuery;
    final searching = query.isNotEmpty;
    final favorites = provider.currentTab == TabType.favorites;
    final error = provider.catalogError;
    final icon = searching
        ? Icons.search_off
        : (favorites ? Icons.favorite_border : Icons.radio);
    final message = searching
        ? 'По запросу "$query" ничего не найдено'
        : (favorites ? 'Нет избранных станций' : 'Нет доступных станций');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error == null) ...[
              Icon(icon, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (favorites)
                const Text(
                  'Добавьте станции в избранное, нажав на иконку сердца',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
            ],
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (searching)
                  OutlinedButton(
                    onPressed: provider.clearSearch,
                    child: const Text(
                      'Очистить поиск',
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (error == null)
                  OutlinedButton(
                    onPressed: provider.reloadActive,
                    child: const Text('Обновить', textAlign: TextAlign.center),
                  ),
                if (!favorites)
                  OutlinedButton(
                    onPressed: provider.refreshServers,
                    child: const Text(
                      'Обновить серверы',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
