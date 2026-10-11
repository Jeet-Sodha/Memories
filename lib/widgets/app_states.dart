import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "No memories yet." empty state (matches the Stitch empty screen).
class EmptyMemoriesView extends StatelessWidget {
  final VoidCallback onCreate;
  final bool compact;
  const EmptyMemoriesView({super.key, required this.onCreate, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 56 : 88,
          height: compact ? 56 : 88,
          decoration: const BoxDecoration(
              color: AppColors.elevated, shape: BoxShape.circle),
          child: Icon(Icons.add_location_alt_outlined,
              size: compact ? 28 : 40, color: AppColors.accentLight),
        ),
        SizedBox(height: compact ? 12 : 20),
        const Text('No memories yet.',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
          'Create your first memory and place it on the map.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onCreate,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentLight,
            foregroundColor: AppColors.onAccent,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26)),
          ),
          child: const Text('Create Memory',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined,
            size: 44, color: AppColors.textSecondary),
        const SizedBox(height: 14),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentLight,
            side: const BorderSide(color: AppColors.accent),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
          ),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
