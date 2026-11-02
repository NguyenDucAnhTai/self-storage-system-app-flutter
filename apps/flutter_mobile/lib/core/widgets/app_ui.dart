import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppTheme.lightMint,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 76,
              height: 76,
              child: Icon(icon, size: 34, color: AppTheme.primaryEmerald),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.wifi_off_outlined,
    title: 'Unable to load',
    message: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Try again'),
    ),
  );
}

class FacilityImage extends StatelessWidget {
  const FacilityImage({super.key, required this.url, this.height = 180});

  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: imageUrl == null || imageUrl.isEmpty
          ? const _ImagePlaceholder()
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const _ImagePlaceholder(),
              errorBuilder: (context, error, stack) =>
                  const _ImagePlaceholder(),
            ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.lightMint,
    child: Center(
      child: Icon(
        Icons.warehouse_outlined,
        size: 42,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
