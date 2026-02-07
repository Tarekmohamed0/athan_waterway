# Athan Waterway 🕌

A simple and elegant desktop application for Mac and Windows that plays custom Athan (Islamic call to prayer) sounds at prayer times in Egypt.

## Features

✨ **Simple & Responsive UI** - Clean, modern interface that's easy to use
🔔 **Custom Athan Sound** - Upload and play your own MP3 file for Athan
⏰ **Real-time Prayer Times** - Automatically fetches accurate prayer times for Egypt using the Aladhan API
🎵 **Audio Player** - Test your custom sound before prayer time
⏱️ **Live Countdown** - See time remaining until next prayer
🖥️ **Cross-platform** - Works on both macOS and Windows

## How It Works

1. **Automatic Prayer Times**: The app fetches today's prayer times for Cairo, Egypt from the Aladhan API
2. **Background Monitoring**: Checks every minute if it's time for any prayer
3. **Custom Sound Playback**: When prayer time arrives, your custom MP3 plays automatically
4. **User-Friendly Interface**: See all prayer times, next prayer countdown, and manage your audio file

## Getting Started

### Prerequisites

- Flutter SDK (3.10 or higher)
- macOS (for Mac builds) or Windows (for Windows builds)

### Installation

1. Clone this repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

### Running the App

**On macOS:**

```bash
flutter run -d macos
```

**On Windows:**

```bash
flutter run -d windows
```

### Building the App

**Build for macOS:**

```bash
flutter build macos
```

The app will be in `build/macos/Build/Products/Release/`

**Build for Windows:**

```bash
flutter build windows
```

The app will be in `build\windows\x64\runner\Release\`

## Usage

1. **Launch the App** - Open Athan Waterway
2. **View Prayer Times** - See today's 5 prayer times displayed automatically
3. **Upload Custom Sound**:
   - Click "Choose MP3" button
   - Select your favorite Athan MP3 file
   - Click "Test" to preview the sound
4. **Let it Run** - Keep the app running in the background
5. **Automatic Playback** - Your custom Athan will play at each prayer time

## Prayer Times

The app displays times for all 5 daily prayers:

- Fajr (Dawn)
- Dhuhr (Noon)
- Asr (Afternoon)
- Maghrib (Sunset)
- Isha (Night)

## Technical Details

### Dependencies

- **audioplayers** - For playing MP3 files
- **file_picker** - For selecting custom audio files
- **http** - For fetching prayer times from API
- **shared_preferences** - For saving user preferences
- **intl** - For date/time formatting

### API

Uses the [Aladhan Prayer Times API](http://aladhan.com/prayer-times-api) with:

- Location: Cairo, Egypt (30.0444°N, 31.2357°E)
- Calculation Method: Egyptian General Authority of Survey

## Troubleshooting

**Audio not playing?**

- Make sure you've selected an MP3 file
- Test the audio using the "Test" button
- Check your system volume

**Prayer times not loading?**

- Check your internet connection
- Click "Refresh Prayer Times" button

**App not working on Windows/Mac?**

- Make sure you have the latest Flutter SDK
- Run `flutter doctor` to check for issues

## License

This project is open source and available for personal use.

## Credits

Prayer times data provided by [Aladhan API](http://aladhan.com/)

---

Made with ❤️ for the Muslim community

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
