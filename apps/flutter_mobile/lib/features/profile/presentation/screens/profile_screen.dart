import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/profile_repository.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../notifications/presentation/notification_bell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Map<String, dynamic>> _profile;
  late final ProfileRepository _repo;
  @override
  void initState() {
    super.initState();
    _repo = ProfileRepository(ref.read(dioProvider));
    _profile = _repo.getMine();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [NotificationBell()],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _profile = _repo.getMine()),
                child: const Text('Could not load profile. Retry'),
              ),
            );
          }
          final data = s.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: Text(
                          user?.name.isNotEmpty == true
                              ? user!.name[0].toUpperCase()
                              : '?',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user?.name ?? '',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', textAlign: TextAlign.center),
                      if (user?.phoneNumber != null)
                        Text(user!.phoneNumber!, textAlign: TextAlign.center),
                      if (data['address'] != null) ...[
                        const SizedBox(height: 4),
                        Text('${data['address']}', textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _edit(data),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit profile'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const AppSectionHeader(title: 'Account settings'),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change password'),
                onTap: () => context.push('/change-password'),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('My storages & contracts'),
                onTap: () => context.push('/contracts'),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                onTap: () => context.push('/notifications'),
              ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic> data) async {
    final address = TextEditingController(text: '${data['address'] ?? ''}');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit address'),
        content: TextField(
          controller: address,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Address'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(address.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    address.dispose();
    if (result == null) return;
    try {
      final updated = await _repo.update({'address': result});
      if (mounted) setState(() => _profile = Future.value(updated));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Profile update failed: $e')));
      }
    }
  }
}
