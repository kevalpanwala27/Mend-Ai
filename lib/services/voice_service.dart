import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isListening = false;
  bool _isRecording = false;
  bool _isSpeaking = false;
  bool _isInitialized = false;
  String _currentSpeaker = '';
  String _recognizedText = '';
  double _speechLevel = 0.0;

  bool get isListening => _isListening;
  bool get isRecording => _isRecording;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;
  String get currentSpeaker => _currentSpeaker;
  String get recognizedText => _recognizedText;
  double get speechLevel => _speechLevel;

  Future<bool> initialize() async {
    try {
      // Request permissions
      final micPermission = await Permission.microphone.request();
      if (micPermission != PermissionStatus.granted) {
        debugPrint('Microphone permission denied');
        return false;
      }

      // Initialize speech to text
      final speechAvailable = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );

      if (!speechAvailable) {
        debugPrint('Speech recognition not available');
        return false;
      }

      // Initialize text to speech
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.8);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Voice service initialization error: $e');
      return false;
    }
  }

  Future<void> startListening(String speakerId) async {
    if (!_isInitialized || _isListening) return;

    try {
      await _speechToText.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          notifyListeners();
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        onSoundLevelChange: (level) {
          _speechLevel = level;
          notifyListeners();
        },
      );

      _isListening = true;
      _currentSpeaker = speakerId;
      _recognizedText = '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
    }
  }

  Future<String?> stopListening() async {
    if (!_isListening) return null;

    try {
      await _speechToText.stop();
      _isListening = false;
      final text = _recognizedText;
      _recognizedText = '';
      _currentSpeaker = '';
      _speechLevel = 0.0;
      notifyListeners();
      return text.isNotEmpty ? text : null;
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
      return null;
    }
  }

  Future<void> startRecording(String speakerId) async {
    if (!_isInitialized || _isRecording) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('Recording permission denied');
        return;
      }

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: '/tmp/mend_recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      _isRecording = true;
      _currentSpeaker = speakerId;
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      _currentSpeaker = '';
      notifyListeners();
      return path;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized || text.isEmpty) return;

    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking text: $e');
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
  }

  void resetSpeechLevel() {
    _speechLevel = 0.0;
    notifyListeners();
  }

  bool get hasSpeechRecognition => _speechToText.isAvailable;

  Future<List<LocaleName>> get availableLocales async =>
      await _speechToText.locales();

  @override
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    _audioRecorder.dispose();
    super.dispose();
  }
}
