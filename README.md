# Mend AI - Couples Therapy Mobile App

An AI-powered couples therapy mobile application built with Flutter that provides voice-based communication guidance, conflict resolution, and relationship improvement tools through AI moderation and structured conversation flows.

## 🎯 Features

- **Voice-Based Communication**: Real-time audio conversations with AI moderation
- **Partner Invitation System**: Easy onboarding for couples
- **Communication Scoring**: Post-conversation feedback on empathy, listening, clarity, and respect
- **Color-Coded Speaking Indicators**: Visual feedback for turn-based conversations
- **Post-Resolution Flow**: Gratitude exercises and bonding activities
- **Insights Dashboard**: Progress tracking and relationship analytics
- **Conflict Resolution**: Structured guidance for healthy communication

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (^3.8.1)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- iOS Simulator, Android Emulator, or physical device
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd mend_ai
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # Run on default device
   flutter run
   
   # Run on specific platforms
   flutter run -d chrome        # Web
   flutter run -d macos         # macOS
   flutter run -d ios           # iOS simulator
   flutter run -d android       # Android emulator
   ```

### Development Commands

```bash
# Install dependencies
flutter pub get

# Run tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Analyze code (lint)
flutter analyze

# Clean build cache
flutter clean

# Build for production
flutter build apk           # Android APK
flutter build ipa           # iOS
flutter build web           # Web
```

## 🏗️ Architecture

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── providers/                # State management
├── screens/                  # UI screens
│   ├── auth/                # Authentication screens
│   ├── chat/                # Voice chat interface
│   ├── main/                # Main app screens
│   ├── onboarding/          # Onboarding flow
│   └── resolution/          # Post-conversation features
├── services/                # Backend services
└── widgets/                 # Reusable UI components
```

### Key Technologies
- **Frontend**: Flutter (Dart)
- **State Management**: Provider/Riverpod
- **Audio Processing**: Flutter sound packages
- **Backend**: Firebase (Authentication, Firestore)
- **UI Framework**: Material Design with custom theming

## 🎨 Design System

### Color Scheme
- **Partner A**: Light blue tint
- **Partner B**: Light pink tint  
- **Base Colors**: Teal, blush pink, muted tones
- **Warning**: Red flash for interruption alerts
- **Theme**: Soft, calming colors for therapeutic environment

### Platform Focus
Primary target is iOS with cross-platform support available through Flutter.

## 🔧 Development

### State Management
The app uses Provider/Riverpod for state management across different screens and features.

### Audio Integration
Voice recording and playback capabilities are implemented using Flutter audio packages with real-time processing for conversation analysis.

### AI Integration
Communication analysis and scoring powered by AI models for relationship guidance and feedback.

## 📱 Current Status

This is an active development project. Current implementation includes:
- ✅ Basic Flutter project structure
- ✅ Development environment setup
- 🔄 Authentication and onboarding flow
- 🔄 Voice communication features
- 🔄 Communication scoring system

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For questions or support, please open an issue in the repository or contact the development team.

---

**Note**: This is a therapeutic application designed to support healthy communication between couples. It is not a replacement for professional therapy or counseling services.
