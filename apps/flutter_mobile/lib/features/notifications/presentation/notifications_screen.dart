import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../data/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.dio});
  final Dio dio;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationRepository _repo;
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _repo = NotificationRepository(widget.dio);
    _future = _repo.list();
  }

  void _reload() => setState(() => _future = _repo.list());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton(
          onPressed: () async {
            await _repo.markAllRead();
            if (mounted) _reload();
          },
          child: const Text('Mark all read'),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('Could not load notifications. Retry'),
            ),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('You are all caught up.'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final notification = items[index];
            return ListTile(
              leading: Icon(
                notification['isRead'] == true
                    ? Icons.notifications_none
                    : Icons.notifications_active,
              ),
              title: Text('${notification['title'] ?? ''}'),
              subtitle: Text('${notification['content'] ?? ''}'),
              onTap: () async {
                if (notification['isRead'] != true) {
                  await _repo.markRead('${notification['id']}');
                }
                if (mounted) _reload();
              },
            );
          },
        );
      },
    ),
  );
}
