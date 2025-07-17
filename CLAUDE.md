# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mend is an AI-powered couples therapy mobile application built with Flutter. The app provides voice-based communication guidance, conflict resolution, and relationship improvement tools through AI moderation and structured conversation flows.

### Core Features to Implement
- **Onboarding Process**: Partner invitation system and relationship questionnaire
- **Voice-Based Chat System**: Real-time communication with AI moderation and color-coded speaking indicators
- **Communication Scoring**: Post-conversation feedback on empathy, listening, clarity, respect, and other metrics
- **Post-Resolution Flow**: Gratitude exercises, shared reflections, and bonding activity suggestions
- **Insights Dashboard**: Progress tracking and relationship analytics

## Development Commands

### Essential Commands
```bash
# Install dependencies
flutter pub get

# Run the app (development)
flutter run

# Run on specific device
flutter run -d chrome        # Web
flutter run -d macos         # macOS
flutter run -d ios           # iOS simulator

# Build for production
flutter build apk           # Android APK
flutter build ipa           # iOS
flutter build web           # Web

# Run tests
flutter test

# Analyze code (lint)
flutter analyze

# Clean build cache
flutter clean
```

### Single Test Execution
```bash
# Run a specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

## Architecture and Structure

### Current State
This is a fresh Flutter project with the default counter app template. The main application structure follows standard Flutter conventions:

- `lib/main.dart`: Entry point with basic MaterialApp setup
- `test/`: Widget and unit tests
- `pubspec.yaml`: Dependencies and project configuration

### Target Architecture
Based on the MVP requirements, the app should be structured around:

1. **Authentication & Onboarding Flow**: Partner invitation and relationship questionnaire
2. **Voice Communication System**: Real-time audio with AI moderation
3. **Scoring & Analytics**: Communication assessment and progress tracking  
4. **UI Theme**: Soft, calming colors (teal, blush pink) with accessibility considerations

### Key Dependencies Needed
- Voice recording and playback capabilities
- Real-time communication framework
- AI/ML integration for conversation analysis
- State management solution (Provider, Riverpod, or Bloc)
- Audio visualization for speaking indicators

## Design Requirements

### Color Scheme
- Light blue tint for Partner A
- Light pink tint for Partner B
- Darker shades for same-gender couples
- Red flash for interruption warnings
- Soft, calming base colors (teal, blush pink, muted tones)

### Platform Focus
Primary target is iOS with future multi-platform support available through Flutter's cross-platform capabilities.

## Development Notes

- Uses Flutter SDK ^3.8.1
- Lint rules configured via `flutter_lints` package
- Material Design components enabled
- No custom rules or specialized tooling currently configured