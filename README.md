# FaceGuard Pro 🛡️

**Advanced Face Recognition & Identification App**

A professional Flutter application that uses ML Kit for accurate face detection and recognition. Register faces with unique IDs and identify them in real-time with high confidence scores.

## ✨ Features

- 📸 **Face Registration**: Capture faces using camera or select from gallery
- 🔍 **Real-time Identification**: Live camera preview with instant face matching
- 🎯 **High Accuracy**: Advanced ML-powered face detection with multi-feature comparison
- 💾 **Local Storage**: SQLite database for secure, offline face data storage
- 🎨 **Modern UI**: Clean, professional interface with Material Design 3
- 📊 **Confidence Scores**: See match confidence percentages for each identification
- 🔐 **Unique IDs**: Each person gets a unique identifier to handle same-name scenarios
- ✅ **Face Validation**: Real-time validation ensuring quality face captures

## 🏗️ Technical Architecture

### Face Recognition Algorithm

The app uses a sophisticated multi-factor matching system:

1. **Facial Landmarks**: Compares positions of eyes, nose, and mouth
2. **Eye Distance**: Measures and compares inter-eye spacing (critical metric)
3. **Pixel Signature**: Analyzes normalized face region pixel patterns
4. **Head Angles**: Considers face rotation for better accuracy
5. **Weighted Scoring**: Combines all factors with optimized weights for best results

**Minimum Match Threshold**: 50% confidence (lowered for better matching)

### Tech Stack

- **Framework**: Flutter 3.44.2 with Dart 3.12.2
- **ML Engine**: Google ML Kit Face Detection
- **Database**: SQLite with sqflite
- **Camera**: camera & image_picker packages
- **UI**: Google Fonts (Poppins), Material Design 3

## 📱 Permissions

### Android
- Camera access
- External storage (read/write)

### iOS
- Camera usage
- Photo library access

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.44.2 or higher
- FVM (Flutter Version Management) - optional but recommended
- Android Studio / Xcode for platform-specific builds

### Installation

1. **Clone or navigate to the project**
   ```bash
   cd /Users/quickensolmac/Projects/faceidentifier
   ```

2. **Install dependencies**
   ```bash
   fvm flutter pub get
   # or simply: flutter pub get
   ```

3. **Run the app**
   ```bash
   # Using FVM
   fvm flutter run
   
   # Or directly
   flutter run
   ```

### Building

```bash
# Android APK
fvm flutter build apk --release

# iOS (requires Mac)
fvm flutter build ios --release

# Android App Bundle (for Play Store)
fvm flutter build appbundle --release
```

## 📖 Usage Guide

### Registering a New Face

1. Open the app and tap **"Register"** on the home screen
2. Tap the camera icon to capture or select an image
3. Ensure:
   - Only one person is in the frame
   - Face is clearly visible and well-lit
   - Eyes are open
   - Face is directly facing the camera
4. Enter the person's full name
5. Tap **"Register Person"**

### Identifying a Face

1. Tap **"Identify"** on the home screen
2. Position your face in the oval guide
3. Tap the **"Identify"** button
4. View the match results with confidence score
5. Tap **"Scan Again"** to identify another person

### Managing Registered Faces

- **View All**: Scroll through the list on the home screen
- **Search**: Use the search bar to find specific persons
- **Details**: Tap any card to view full details
- **Delete**: Use the menu (⋮) or details dialog to remove a person

## 🎯 Best Practices for Accuracy

1. **Good Lighting**: Ensure faces are well-lit during registration and identification
2. **Direct Angle**: Face the camera straight on, avoid side angles
3. **Clear Background**: Use simple backgrounds to avoid confusion
4. **Consistent Distance**: Maintain similar distance from camera for best results
5. **Multiple Registrations**: For critical use cases, register the same person multiple times in different lighting

## 🔧 Configuration

### Adjusting Match Threshold

Edit `lib/services/face_recognition_service.dart`:

```dart
Future<MatchResult?> findBestMatch(
  String targetFaceFeatures,
  List<PersonModel> persons, {
  double threshold = 70.0, // Change this value (0-100)
}) async {
```

Lower values = more lenient matching
Higher values = stricter matching

### Customizing UI Colors

Edit `lib/main.dart`:

```dart
seedColor: const Color(0xFF6C63FF), // Change app color theme
```

## 📦 Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   └── person_model.dart             # Data model for persons
├── database/
│   └── database_helper.dart          # SQLite database operations
├── services/
│   └── face_recognition_service.dart # ML Kit face detection & matching
└── screens/
    ├── home_screen.dart              # Main dashboard
    ├── register_face_screen.dart     # Face registration UI
    └── identify_face_screen.dart     # Face identification UI
```

## 🐛 Troubleshooting

### Camera not working
- Check permissions in device settings
- Restart the app
- Ensure camera is not used by another app

### Face not detected
- Improve lighting conditions
- Move closer to the camera
- Ensure face is not obscured

### Low confidence scores
- Re-register the person with better quality images
- Ensure consistent lighting between registration and identification
- Check that face is clearly visible in both scenarios

### Build issues
- Run `fvm flutter clean && fvm flutter pub get`
- Update Flutter: `fvm flutter upgrade`
- Check Android SDK and Xcode are up to date

## 📄 License

This project is created for demonstration purposes. Modify as needed for your use case.

## 🤝 Contributing

Feel free to fork and improve! Some ideas:
- Add face recognition for multiple faces simultaneously
- Implement cloud sync for face data
- Add biometric authentication for app access
- Export/Import face database
- Add analytics and reporting

## 📧 Support

Package ID: `com.quickensol.faceguardpro`

For issues and questions, please check the troubleshooting section first.

---

Built with ❤️ using Flutter and ML Kit
