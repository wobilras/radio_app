import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/radio_provider.dart';
import '../widgets/app_bar.dart';
import '../widgets/radio_station_tile.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      return 2;
    } else if (screenWidth < 900) {
      return 3;
    } else if (screenWidth < 1200) {
      return 4;
    } else {
      return 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radioProvider = Provider.of<RadioProvider>(context);

    return Scaffold(
      appBar: MainAppBar(
        currentTab: radioProvider.currentTab,
        onTabChanged: radioProvider.setCurrentTab,
        searchController: radioProvider.searchController,
        onSearchClear: radioProvider.clearSearch,
      ),
      body: Consumer<RadioProvider>(
        builder: (context, radioProvider, child) {
          return _buildContent(context, radioProvider);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, RadioProvider radioProvider) {
    if (radioProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              _getLoadingText(radioProvider.currentTab),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Показываем индикатор поиска отдельно от основной загрузки
    Widget content = _buildStationsList(context, radioProvider);

    if (radioProvider.isSearching && radioProvider.searchQuery.isNotEmpty) {
      content = Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Поиск станций...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

    Widget _buildStationsList(BuildContext context, RadioProvider radioProvider) {
      if (radioProvider.error != null) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                SizedBox(height: 16),
                Text(
                  radioProvider.error!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => radioProvider.loadStations(),
                      icon: Icon(Icons.refresh),
                      label: Text('Повторить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => radioProvider.refreshServers(),
                      icon: Icon(Icons.dns),
                      label: Text('Обновить серверы'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (radioProvider.currentPlayingId != null) ...[
                      SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => radioProvider.stopCurrentStation(),
                        icon: Icon(Icons.stop),
                        label: Text('Остановить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }

      final stations = radioProvider.filteredStations;

      if (stations.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyIcon(radioProvider.currentTab, radioProvider.searchQuery),
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  _getEmptyMessage(radioProvider.currentTab, radioProvider.searchQuery),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_shouldShowSubMessage(radioProvider.currentTab, radioProvider.searchQuery))
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      _getEmptySubMessage(radioProvider.currentTab),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 24),
                if (radioProvider.searchQuery.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => radioProvider.clearSearch(),
                        icon: Icon(Icons.clear),
                        label: Text('Очистить поиск'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => radioProvider.refreshServers(),
                        icon: Icon(Icons.dns),
                        label: Text('Обновить серверы'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => radioProvider.loadStations(),
                        icon: Icon(Icons.refresh),
                        label: Text('Обновить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => radioProvider.refreshServers(),
                        icon: Icon(Icons.dns),
                        label: Text('Обновить серверы'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => radioProvider.loadStations(),
        child: GridView.builder(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getCrossAxisCount(context),
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
            childAspectRatio: 0.8,
          ),
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            final isPlaying = radioProvider.currentPlayingId == station.stationuuid;
            final isFavorite = radioProvider.isFavorite(station.stationuuid);

            return RadioStationTile(
              station: station,
              isPlaying: isPlaying,
              isFavorite: isFavorite,
              onTap: () => radioProvider.playStation(station.stationuuid),
              onFavoriteToggle: () => radioProvider.toggleFavorite(station.stationuuid),
            );
          },
        ),
      );
    }

    String _getLoadingText(TabType tab) {
      switch (tab) {
        case TabType.stations:
          return 'Загрузка популярных станций...';
        case TabType.favorites:
          return 'Загрузка избранных станций...';
      }
    }

    IconData _getEmptyIcon(TabType tab, String searchQuery) {
      if (searchQuery.isNotEmpty) {
        return Icons.search_off;
      }

      switch (tab) {
        case TabType.stations:
          return Icons.radio;
        case TabType.favorites:
          return Icons.favorite_border;
      }
    }

    String _getEmptyMessage(TabType tab, String searchQuery) {
      if (searchQuery.isNotEmpty) {
        return 'По запросу "$searchQuery"\nничего не найдено';
      }

      switch (tab) {
        case TabType.stations:
          return 'Нет доступных станций';
        case TabType.favorites:
          return 'Нет избранных станций';
      }
    }

    bool _shouldShowSubMessage(TabType tab, String searchQuery) {
      return tab == TabType.favorites && searchQuery.isEmpty;
    }

    String _getEmptySubMessage(TabType tab) {
      switch (tab) {
        case TabType.favorites:
          return 'Добавьте станции в избранное,\nнажав на иконку сердца';
        default:
          return '';
      }
    }
  }