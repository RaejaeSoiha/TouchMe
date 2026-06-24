import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/layout/responsive.dart';
import '../data/subscriptions_repository.dart';

final plansProvider = FutureProvider<List<SubscriptionPlan>>(
  (ref) => ref.watch(subscriptionsRepositoryProvider).plans(),
);
final mySubscriptionProvider = FutureProvider<UserSubscription?>(
  (ref) => ref.watch(subscriptionsRepositoryProvider).mine(),
);

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final subscription = ref.watch(mySubscriptionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('TouchMe Plus', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ResponsiveBody(
        child: ListView(
        children: [
          subscription.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (sub) => sub == null
                ? const SizedBox.shrink()
                : Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified, color: Color(0xFFE84A72)),
                      title: Text('Active: ${sub.plan.name}'),
                      subtitle: Text(
                        'Renews ${sub.currentPeriodEnd.toLocal().toString().split(' ').first}',
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          const Text(
            'TouchMe Plus unlocks:\n'
            '• Search up to 200 km away\n'
            '• Explore people in another city\n'
            '• Featured placement in nearby results',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
          plans.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load plans: $error'),
            data: (items) => Column(
              children: items
                  .map(
                    (plan) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '\$${(plan.priceCents / 100).toStringAsFixed(2)}/month',
                        ),
                        trailing: FilledButton(
                          onPressed: () async {
                            try {
                              final url = await ref
                                  .read(subscriptionsRepositoryProvider)
                                  .checkout(plan.code);
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not start checkout. Try again.'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Subscribe'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () async {
              try {
                await ref.read(subscriptionsRepositoryProvider).activateBoost();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Featured placement active for 30 minutes'),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not activate boost. Try again.'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.rocket_launch_outlined),
            label: const Text('Boost my profile'),
          ),
        ],
      ),
      ),
    );
  }
}
