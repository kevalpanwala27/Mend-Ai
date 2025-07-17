import 'package:flutter/material.dart';

class InsightsDashboardScreen extends StatelessWidget {
  const InsightsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Summary
            Text(
              'Weekly Summary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.calendar_today, color: Colors.teal),
                title: Text('2 sessions completed this week'),
                subtitle: Text('Communication scores improved by 10%'),
              ),
            ),
            const SizedBox(height: 32),
            // Communication Trends
            Text(
              'Communication Trends',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text('Graph Placeholder')),
            ),
            const SizedBox(height: 32),
            // Saved Reflections
            Text(
              'Saved Reflections',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.favorite, color: Colors.pinkAccent),
                title: Text('"I appreciated how you listened to me."'),
                subtitle: Text('Session on May 10, 2024'),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.lightbulb, color: Colors.amber),
                title: Text('"We agreed to spend more quality time together."'),
                subtitle: Text('Session on May 3, 2024'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
