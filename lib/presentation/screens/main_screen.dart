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
      return 3;
    } else if (screenWidth < 900) {
      return 4;
    } else if (screenWidth < 1200) {
      return 5;
    } else {
      return 6;
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
              'Загрузка станций...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (radioProvider.error != null) {
      return Center(
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
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => radioProvider.loadStations(),
              child: Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final stations = radioProvider.filteredStations;

    if (stations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              radioProvider.currentTab == TabType.favorites
                  ? Icons.favorite_border
                  : Icons.radio,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              radioProvider.searchQuery.isNotEmpty
                  ? 'Станции не найдены'
                  : radioProvider.currentTab == TabType.favorites
                  ? 'Нет избранных станций'
                  : 'Нет доступных станций',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (radioProvider.currentTab == TabType.favorites && radioProvider.searchQuery.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Добавьте станции в избранное,\nнажав на иконку сердца',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
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
          childAspectRatio: 0.7,
        ),
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final station = stations[index];
          final isPlaying = radioProvider.currentPlayingId == station.id;
          final isFavorite = radioProvider.isFavorite(station.id);

          return RadioStationTile(
            station: station,
            isPlaying: isPlaying,
            isFavorite: isFavorite,
            onTap: () => radioProvider.playStation(station.id),
            onFavoriteToggle: () => radioProvider.toggleFavorite(station.id),
          );
        },
      ),
    );
  }
}