import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:radio_app/data/repositories/radio_repository.dart';
import 'package:radio_app/data/storage.dart';
import 'package:radio_app/presentation/screens/main_screen.dart';
import 'package:radio_app/providers/radio_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RadioProvider(
            repository: RadioRepositoryImpl(),
            storage: StorageService(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Radio Browser',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.grey[100],
          appBarTheme: AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
