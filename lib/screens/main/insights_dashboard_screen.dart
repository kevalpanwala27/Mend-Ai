import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';

class InsightsDashboardScreen extends StatelessWidget {
  const InsightsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights Dashboard')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.background,
              Color(0xFFF8F9FA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Consumer<FirebaseAppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekly Summary
                _buildWeeklySummary(context, appState),
                const SizedBox(height: 32),
                // Communication Trends
                _buildCommunicationTrends(context, appState),
                const SizedBox(height: 32),
                // Saved Reflections
                _buildSavedReflections(context, appState),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildWeeklySummary(BuildContext context, FirebaseAppState appState) {
    final weeklyStats = _calculateWeeklyStats(appState);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Summary',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.calendar_today, color: AppTheme.primary),
            title: Text('${weeklyStats['sessionsThisWeek']} sessions completed this week'),
            subtitle: Text(weeklyStats['improvement'] != null 
                ? 'Communication scores ${weeklyStats['improvement'] > 0 ? 'improved' : 'decreased'} by ${weeklyStats['improvement'].abs().toStringAsFixed(1)}%'
                : 'Complete more sessions to see improvement trends'),
          ),
        ),
        const SizedBox(height: 12),
        if (weeklyStats['totalSessions'] > 0) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    'Total Sessions',
                    '${weeklyStats['totalSessions']}',
                    Icons.chat_rounded,
                  ),
                  _buildStatItem(
                    context,
                    'Avg Score',
                    '${weeklyStats['averageScore'].toStringAsFixed(1)}/10',
                    Icons.star_rounded,
                  ),
                  _buildStatItem(
                    context,
                    'Total Time',
                    '${weeklyStats['totalMinutes']}m',
                    Icons.access_time_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCommunicationTrends(BuildContext context, FirebaseAppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Communication Trends',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: _buildScoreChart(context, appState),
        ),
      ],
    );
  }

  Widget _buildScoreChart(BuildContext context, FirebaseAppState appState) {
    final recentSessions = appState.getRecentSessions(limit: 7);
    
    if (recentSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 48, color: AppTheme.primary.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'Complete sessions to see trends',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (recentSessions.length - 1).toDouble(),
          minY: 0,
          maxY: 10,
          lineBarsData: [
            LineChartBarData(
              spots: recentSessions.asMap().entries.map((entry) {
                final index = entry.key;
                final session = entry.value;
                final score = session.scores?.averageScore ?? 0.0;
                return FlSpot(index.toDouble(), score);
              }).toList(),
              isCurved: true,
              color: AppTheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedReflections(BuildContext context, FirebaseAppState appState) {
    final sessionsWithReflections = appState.getRecentSessions()
        .where((session) => session.reflection != null && session.reflection!.isNotEmpty)
        .take(5)
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved Reflections',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (sessionsWithReflections.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 48,
                    color: AppTheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reflections yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete conversation sessions to see your reflections here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...sessionsWithReflections.map((session) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(Icons.favorite, color: AppTheme.secondary),
              title: Text(
                '"${session.reflection}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('Session on ${_formatDate(session.startTime)}'),
            ),
          )),
      ],
    );
  }

  Map<String, dynamic> _calculateWeeklyStats(FirebaseAppState appState) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    final allSessions = appState.getRecentSessions(limit: 100);
    final sessionsThisWeek = allSessions.where((session) =>
        session.startTime.isAfter(weekStart) && session.startTime.isBefore(weekEnd)).toList();
    
    final totalSessions = allSessions.length;
    final totalMinutes = allSessions.fold<int>(0, (sum, session) => sum + session.duration.inMinutes);
    
    double? improvement;
    if (allSessions.length >= 2) {
      final recentScores = allSessions.take(3).map((s) => s.scores?.averageScore ?? 0.0).toList();
      final olderScores = allSessions.skip(3).take(3).map((s) => s.scores?.averageScore ?? 0.0).toList();
      
      if (recentScores.isNotEmpty && olderScores.isNotEmpty) {
        final recentAvg = recentScores.reduce((a, b) => a + b) / recentScores.length;
        final olderAvg = olderScores.reduce((a, b) => a + b) / olderScores.length;
        improvement = ((recentAvg - olderAvg) / olderAvg * 100);
      }
    }
    
    final averageScore = allSessions.isNotEmpty
        ? allSessions.map((s) => s.scores?.averageScore ?? 0.0).reduce((a, b) => a + b) / allSessions.length
        : 0.0;
    
    return {
      'sessionsThisWeek': sessionsThisWeek.length,
      'totalSessions': totalSessions,
      'totalMinutes': totalMinutes,
      'averageScore': averageScore,
      'improvement': improvement,
    };
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
