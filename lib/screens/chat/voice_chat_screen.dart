import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/voice_service.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../models/communication_session.dart';
import '../resolution/post_resolution_screen.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  late VoiceService _voiceService;
  late AIService _aiService;
  String? _currentSpeaker;
  bool _isInitialized = false;
  DateTime? _lastMessageTime;
  bool _conversationStarted = false;
  final ScrollController _scrollController = ScrollController();

  // For interruption flash
  bool _showInterruptionFlash = false;

  // For waveform animation
  late AnimationController _waveformController;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceService();
    _aiService = AIService();
    _initializeServices();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  Future<void> _initializeServices() async {
    final success = await _voiceService.initialize();
    if (success) {
      setState(() => _isInitialized = true);
      _startConversation();
    } else {
      _showError('Failed to initialize voice services');
    }
  }

  void _startConversation() {
    context.read<AppState>().startCommunicationSession();
    _conversationStarted = true;

    // Start with AI greeting
    final starter = _aiService.getConversationStarter();
    context.read<AppState>().addMessage('AI', starter, MessageType.ai);
    _voiceService.speak(starter);

    _scrollToBottom();
  }

  void _startListening(String speakerId) {
    if (!_isInitialized || _voiceService.isListening) return;

    setState(() => _currentSpeaker = speakerId);
    _voiceService.startListening(speakerId);
  }

  void _stopListening() async {
    if (!_voiceService.isListening) return;

    final recognizedText = await _voiceService.stopListening();
    if (recognizedText != null && recognizedText.isNotEmpty) {
      _processMessage(recognizedText);
    }
    setState(() => _currentSpeaker = null);
  }

  void _processMessage(String text) {
    final appState = context.read<AppState>();
    final currentSession = appState.currentSession;

    if (currentSession == null || _currentSpeaker == null) return;

    // Check for interruption
    final timeSinceLastMessage = _lastMessageTime != null
        ? DateTime.now().difference(_lastMessageTime!)
        : const Duration(minutes: 5);

    final wasInterrupted = _aiService.detectInterruption(
      currentSession.messages,
      timeSinceLastMessage,
    );

    if (wasInterrupted) {
      _handleInterruption();
      return;
    }

    // Add user message
    appState.addMessage(_currentSpeaker!, text, MessageType.user);
    _lastMessageTime = DateTime.now();

    // Generate AI response
    _generateAIResponse(text, currentSession.messages);

    _scrollToBottom();
  }

  void _handleInterruption() {
    final otherPartner = context.read<AppState>().getOtherPartner();
    final warningMessage = _aiService.getInterruptionWarning(
      otherPartner?.name ?? 'your partner',
    );

    // Flash red background
    _showInterruptionWarning();

    // Add system message and speak it
    context.read<AppState>().addMessage(
      'AI',
      warningMessage,
      MessageType.system,
    );
    _voiceService.speak(warningMessage);
  }

  void _showInterruptionWarning() {
    setState(() {
      _showInterruptionFlash = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showInterruptionFlash = false;
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please let your partner finish speaking'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _generateAIResponse(String userMessage, List<Message> messages) {
    final tone = _aiService.analyzeEmotionalTone(userMessage);
    final response = _aiService.generateContextualResponse(messages, tone);

    // Add AI response
    context.read<AppState>().addMessage('AI', response, MessageType.ai);
    _voiceService.speak(response);

    _scrollToBottom();
  }

  void _endConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PostResolutionScreen()),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentSession = appState.currentSession;
        final currentPartner = appState.getCurrentPartner();
        final otherPartner = appState.getOtherPartner();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Guided Conversation'),
            actions: [
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _endConversation,
              ),
            ],
          ),
          body: Stack(
            children: [
              !_isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // Partner indicators
                        _buildPartnerIndicators(
                          currentPartner?.name ?? 'You',
                          otherPartner?.name ?? 'Partner',
                        ),
                        // Messages
                        Expanded(
                          child: _buildMessagesList(
                            currentSession?.messages ?? [],
                          ),
                        ),
                        // Voice controls
                        _buildVoiceControls(
                          currentPartner?.id ?? 'A',
                          otherPartner?.id ?? 'B',
                        ),
                      ],
                    ),
              // Interruption flash overlay
              if (_showInterruptionFlash)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _showInterruptionFlash ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(color: Colors.red.withOpacity(0.5)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartnerIndicators(String partnerAName, String partnerBName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _currentSpeaker != null
            ? AppTheme.getPartnerColor(_currentSpeaker!).withOpacity(0.3)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPartnerIndicator('A', partnerAName)),
          const SizedBox(width: 16),
          Expanded(child: _buildPartnerIndicator('B', partnerBName)),
        ],
      ),
    );
  }

  Widget _buildPartnerIndicator(String partnerId, String name) {
    final isCurrentSpeaker = _currentSpeaker == partnerId;
    final isListening = _voiceService.isListening && isCurrentSpeaker;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentSpeaker
            ? AppTheme.getPartnerColor(partnerId)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.getPartnerColor(partnerId, isDark: true),
          width: isCurrentSpeaker ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.getSpeakingIndicatorColor(partnerId),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: isCurrentSpeaker
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          if (isListening) _buildVoiceWaveform(),
        ],
      ),
    );
  }

  Widget _buildVoiceWaveform() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        final scale = 1.0 + 0.5 * _waveformController.value;
        return Row(
          children: List.generate(3, (i) {
            final barHeight = 12.0 + (i * 6) * scale;
            return Container(
              width: 4,
              height: barHeight,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMessagesList(List<Message> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isAI =
        message.type == MessageType.ai || message.type == MessageType.system;
    final isSystem = message.type == MessageType.system;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isAI) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.getPartnerColor(message.speakerId),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  message.speakerId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSystem
                    ? AppTheme.interruptionColor.withOpacity(0.1)
                    : isAI
                    ? Theme.of(context).colorScheme.surfaceVariant
                    : AppTheme.getPartnerColor(
                        message.speakerId,
                      ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: isSystem
                    ? Border.all(color: AppTheme.interruptionColor)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAI)
                    Row(
                      children: [
                        Icon(
                          isSystem ? Icons.warning : Icons.psychology,
                          size: 16,
                          color: isSystem
                              ? AppTheme.interruptionColor
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSystem ? 'System' : 'AI Guide',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSystem
                                ? AppTheme.interruptionColor
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),

                  if (isAI) const SizedBox(height: 4),

                  Text(
                    message.content,
                    style: TextStyle(
                      color: isSystem
                          ? AppTheme.interruptionColor
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _formatTime(message.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isAI) const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildVoiceControls(String partnerAId, String partnerBId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildVoiceButton(partnerAId, 'A')),
          const SizedBox(width: 16),
          Expanded(child: _buildVoiceButton(partnerBId, 'B')),
        ],
      ),
    );
  }

  Widget _buildVoiceButton(String partnerId, String label) {
    final isCurrentSpeaker = _currentSpeaker == partnerId;
    final isListening = _voiceService.isListening && isCurrentSpeaker;

    return GestureDetector(
      onTapDown: (_) => _startListening(partnerId),
      onTapUp: (_) => _stopListening(),
      onTapCancel: () => _stopListening(),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isListening
              ? AppTheme.getPartnerColor(partnerId)
              : AppTheme.getPartnerColor(partnerId).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.getPartnerColor(partnerId, isDark: true),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isListening ? Icons.mic : Icons.mic_off,
              size: 32,
              color: AppTheme.getPartnerColor(partnerId, isDark: true),
            ),
            const SizedBox(height: 4),
            Text(
              isListening ? 'Listening...' : 'Hold to Speak',
              style: TextStyle(
                color: AppTheme.getPartnerColor(partnerId, isDark: true),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime).inSeconds;

    if (difference < 60) {
      return 'Just now';
    } else if (difference < 3600) {
      return '${difference ~/ 60}m ago';
    } else {
      return '${difference ~/ 3600}h ago';
    }
  }

  @override
  void dispose() {
    _voiceService.dispose();
    _scrollController.dispose();
    _waveformController.dispose();
    super.dispose();
  }
}
