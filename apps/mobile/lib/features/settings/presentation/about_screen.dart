import 'package:flutter/material.dart';
import '../../../core/layout/responsive.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About TouchMe', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ResponsiveBody(
        child: ListView(
          children: [
            const Icon(Icons.favorite_rounded, size: 72, color: Color(0xFFE84A72)),
            const SizedBox(height: 16),
            Text(
              'TouchMe',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Version 1.0.0',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'TouchMe helps you find people nearby, add friends, and chat openly — '
              'like a local social network.\n\n'
              '• Browse people sorted by distance\n'
              '• Filter by gender, age, and radius\n'
              '• Send friend requests\n'
              '• Message anyone without matching\n'
              '• Block and report for safety',
              style: TextStyle(height: 1.5, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Built with'),
                subtitle: const Text('Flutter · NestJS · PostgreSQL/PostGIS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
