import 'package:flutter/material.dart';

import '../../providers/radio_provider.dart';

class MainAppBar extends StatefulWidget implements PreferredSizeWidget {
  final TabType currentTab;
  final ValueChanged<TabType> onTabChanged;
  final TextEditingController searchController;
  final VoidCallback? onSearchClear;

  const MainAppBar({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.searchController,
    this.onSearchClear,
  });

  @override
  Size get preferredSize => const Size.fromHeight(160);

  @override
  State<MainAppBar> createState() => _MainAppBarState();
}

class _MainAppBarState extends State<MainAppBar> {
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[700]!, Colors.blue[500]!],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Listener(
                  onPointerDown: (_) {
                    if (widget.currentTab == TabType.stations) {
                      _searchFocus.requestFocus();
                    }
                  },
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.searchController,
                    builder: (context, value, _) => TextField(
                      controller: widget.searchController,
                      focusNode: _searchFocus,
                      enabled: widget.currentTab == TabType.stations,
                      decoration: InputDecoration(
                        hintText: 'Поиск радиостанций...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                onPressed: widget.onSearchClear,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Вкладки
              Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      title: 'Популярные',
                      icon: Icons.trending_up,
                      isSelected: widget.currentTab == TabType.stations,
                      onTap: () => widget.onTabChanged(TabType.stations),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _TabButton(
                      title: 'Избранное',
                      icon: Icons.favorite,
                      isSelected: widget.currentTab == TabType.favorites,
                      onTap: () => widget.onTabChanged(TabType.favorites),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.7);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),
        child: Semantics(
          selected: isSelected,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
