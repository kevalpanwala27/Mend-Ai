import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animated_card.dart';
import '../main/insights_dashboard_screen.dart';
import 'session_waiting_room_screen.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Font scale for accessibility
  final double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_fontScale)),
          child: Scaffold(
            backgroundColor: Colors.black, // Set solid black background
            appBar: AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                ).createShader(bounds),
                child: const Text(
                  'Mend',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AppTheme.primary,
                      size: 20,
                      semanticLabel: 'Insights Dashboard',
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InsightsDashboardScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppTheme.spacingM),
              ],
            ),
            body: Container(
              decoration: const BoxDecoration(
                color:
                    Colors.black, // Solid black background instead of gradient
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppTheme.spacingL.w),
                    child: AnimationLimiter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 800),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: [
                            // Welcome Section
                            Semantics(
                              label: 'Welcome Section',
                              child: _buildWelcomeSection(context, appState),
                            ),
                            SizedBox(height: AppTheme.spacingXL.h),
                            // Quick Stats Card
                            Semantics(
                              label: 'Quick Stats',
                              child: _buildQuickStatsCard(context, appState),
                            ),
                            SizedBox(height: AppTheme.spacingXL.h),
                            // Session Actions
                            Semantics(
                              label: 'Session Actions',
                              child: _buildSessionActions(context),
                            ),
                            SizedBox(height: AppTheme.spacingXL.h),
                            // Features Overview
                            Semantics(
                              label: 'Features Overview',
                              child: _buildFeaturesOverview(context),
                            ),
                            SizedBox(height: AppTheme.spacingXL.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection(BuildContext context, FirebaseAppState appState) {
    final currentPartner = appState.getCurrentPartner();
    final timeOfDay = DateTime.now().hour;
    String greeting = 'Good morning';
    if (timeOfDay >= 12 && timeOfDay < 17) {
      greeting = 'Good afternoon';
    } else if (timeOfDay >= 17) {
      greeting = 'Good evening';
    }

    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, ${currentPartner?.name ?? 'there'}!',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Ready to strengthen your relationship today?',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(BuildContext context, FirebaseAppState appState) {
    final recentSessions = appState.getRecentSessions(limit: 10);
    final totalSessions = recentSessions.length;
    final avgScore = totalSessions > 0
        ? recentSessions
                  .map((s) => s.scores?.averageScore ?? 0.0)
                  .reduce((a, b) => a + b) /
              totalSessions
        : 0.0;

    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: AppTheme.primary, size: 24),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                'Your Progress',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Sessions',
                  totalSessions.toString(),
                  Icons.chat_rounded,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Avg Score',
                  totalSessions > 0
                      ? '${avgScore.toStringAsFixed(1)}/10'
                      : '--',
                  Icons.star_rounded,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Streak',
                  '${_calculateStreak(recentSessions)} days',
                  Icons.local_fire_department_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 24),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSessionActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start a Conversation',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Text(
          'Choose how you\'d like to begin your guided communication session',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacingL),
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Start New Session',
            icon: Icons.add_circle_outline_rounded,
            onPressed: () => _showStartSessionDialog(context),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Join Session',
            icon: Icons.group_add_rounded,
            isSecondary: true,
            onPressed: () => _showJoinSessionDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesOverview(BuildContext context) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Mend Helps',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildFeatureItem(
            Icons.record_voice_over_rounded,
            'Real-time Guidance',
            'AI-powered conversation moderation and live feedback',
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildFeatureItem(
            Icons.psychology_rounded,
            'Smart Insights',
            'Detailed analysis of communication patterns and growth',
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildFeatureItem(
            Icons.favorite_rounded,
            'Stronger Bond',
            'Personalized activities to deepen your connection',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.glassmorphicDecoration(
        borderRadius: AppTheme.radiusL,
        hasGlow: false,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondary.withValues(alpha: 0.2),
                  AppTheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: AppTheme.secondary, size: 24),
          ),
          const SizedBox(width: AppTheme.spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStartSessionDialog(BuildContext context) {
    final sessionCode = _generateSessionCode();
    final userId = context.read<FirebaseAppState>().user?.uid ?? '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              const Text('Session Code'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  sessionCode,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48, // Smaller height for dialog buttons
                      child: GradientButton(
                        text: 'Copy',
                        icon: Icons.copy_rounded,
                        isSecondary: true,
                        fontSize: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingS,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: sessionCode));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Session code copied!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: SizedBox(
                      height: 48, // Smaller height for dialog buttons
                      child: GradientButton(
                        text: 'Share',
                        icon: Icons.share_rounded,
                        fontSize: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingS,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Share.share(
                            'Join my Mend session with code: $sessionCode\n\nDownload Mend to start improving your relationship communication together!',
                            subject: 'Join my Mend session',
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Share this code with your partner so you can both join the same session.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacingL),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Go to Waiting Room',
                  icon: Icons.meeting_room_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionWaitingRoomScreen(
                          sessionCode: sessionCode,
                          userId: userId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showJoinSessionDialog(BuildContext context) {
    final controller = TextEditingController();
    final userId = context.read<FirebaseAppState>().user?.uid ?? '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              const Text('Join Session'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Enter Session Code',
                  hintText: '6-character code',
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
              ),
              const SizedBox(height: AppTheme.spacingL),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Join Session',
                  icon: Icons.login_rounded,
                  onPressed: () {
                    final sessionCode = controller.text.trim().toUpperCase();
                    if (sessionCode.isEmpty || sessionCode.length != 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid 6-character session code',
                          ),
                          backgroundColor: AppTheme.interruptionColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionWaitingRoomScreen(
                          sessionCode: sessionCode,
                          userId: userId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _generateSessionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  int _calculateStreak(List<dynamic> sessions) {
    if (sessions.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 30; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final hasSessionOnDate = sessions.any((session) {
        final sessionDate = DateTime(
          session.startTime.year,
          session.startTime.month,
          session.startTime.day,
        );
        return sessionDate == checkDate;
      });

      if (hasSessionOnDate) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }
}
