import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/safety/data/safety_repository.dart';

Future<void> showBlockReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text('Block $displayName'),
            subtitle: const Text('They cannot message you or see you on Nearby'),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(safetyRepositoryProvider).block(userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$displayName blocked')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.orange),
            title: Text('Report $displayName'),
            onTap: () async {
              Navigator.pop(context);
              final reason = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Report reason'),
                  children: [
                    for (final item in const [
                      'HARASSMENT',
                      'SPAM',
                      'FAKE_PROFILE',
                      'INAPPROPRIATE_CONTENT',
                      'OTHER',
                    ])
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, item),
                        child: Text(item.replaceAll('_', ' ')),
                      ),
                  ],
                ),
              );
              if (reason == null) return;
              await ref.read(safetyRepositoryProvider).report(
                userId: userId,
                reason: reason,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thank you.')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

void showCommunityGuidelines(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Community guidelines'),
      content: const Text(
        'TouchMe is for genuine nearby connections.\n\n'
        '• Be respectful in messages\n'
        '• Do not harass or spam\n'
        '• Report fake profiles or abuse\n'
        '• Block anyone who makes you uncomfortable',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
      ],
    ),
  );
}
