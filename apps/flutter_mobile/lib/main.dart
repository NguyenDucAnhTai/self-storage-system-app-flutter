import 'package:flutter/material.dart';

void main() {
  runApp(const StorageHubApp());
}

class StorageHubApp extends StatelessWidget {
  const StorageHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF0B927E);

    return MaterialApp(
      title: 'StorageHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const StorageHubHomePage(),
    );
  }
}

class StorageHubHomePage extends StatelessWidget {
  const StorageHubHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'StorageHub',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
