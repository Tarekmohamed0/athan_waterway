# Build Instructions for Athan Waterway

## Building for macOS (Current Machine)

```bash
flutter build macos --release
```

The built app will be located at:

```
build/macos/Build/Products/Release/athan_waterway.app
```

You can then:

1. Copy the `.app` file to your Applications folder
2. Or create a DMG installer for distribution

---

## Building for Windows

**Note:** You must be on a Windows machine to build for Windows.

### Prerequisites on Windows:

1. Install Flutter SDK
2. Install Visual Studio 2022 or later with "Desktop development with C++" workload
3. Run `flutter doctor` to verify setup

### Build Steps:

1. **Clone or copy this project to Windows machine**

2. **Install dependencies:**

   ```cmd
   flutter pub get
   ```

3. **Build release version:**

   ```cmd
   flutter build windows --release
   ```

4. **Find the built application:**

   The executable will be located at:

   ```
   build\windows\x64\runner\Release\
   ```

5. **Distribution:**

   Copy the entire `Release` folder contents, which includes:
   - `athan_waterway.exe` - The main executable
   - All DLL files needed for the app
   - `data` folder with Flutter assets

### Creating an Installer (Optional)

For easier distribution on Windows, you can create an installer using:

**Option 1: Inno Setup (Recommended)**

- Download from: https://jrsoftware.org/isinfo.php
- Create an installer script to package all files
- Example script included below

**Option 2: MSIX Package**

```cmd
flutter pub add msix
flutter pub get
flutter build windows
dart run msix:create
```

---

## Inno Setup Script for Windows Installer

Create a file `windows_installer.iss`:

```inno
[Setup]
AppName=Athan Waterway
AppVersion=1.0.0
DefaultDirName={pf}\Athan Waterway
DefaultGroupName=Athan Waterway
OutputDir=installer_output
OutputBaseFilename=AthanWaterwaySetup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\Athan Waterway"; Filename: "{app}\athan_waterway.exe"
Name: "{commondesktop}\Athan Waterway"; Filename: "{app}\athan_waterway.exe"

[Run]
Filename: "{app}\athan_waterway.exe"; Description: "Launch Athan Waterway"; Flags: postinstall nowait skipifsilent
```

---

## Testing on Windows

After building, test the application:

1. **Run the executable** directly from the Release folder
2. **Test audio playback** - select an MP3 file
3. **Verify network access** - check if prayer times load
4. **Test notifications** - wait for prayer time or change system time to test

---

## Distribution Checklist

Before distributing to users:

- ✅ Test on clean Windows machine without Flutter installed
- ✅ Include all DLL files from Release folder
- ✅ Include the `data` folder with all assets
- ✅ Test MP3 file selection and playback
- ✅ Test internet connectivity for prayer times
- ✅ Create installer for easy installation
- ✅ Test on Windows 10 and Windows 11

---

## File Size

Expected sizes:

- macOS app: ~60-80 MB
- Windows app: ~50-70 MB (Release folder)
- Windows installer: ~30-40 MB (compressed)

---

## Troubleshooting

### Windows Build Issues:

**Error: Visual Studio not found**

- Install Visual Studio 2022 with C++ desktop development
- Run `flutter doctor -v` to verify

**Error: Missing dependencies**

- Run `flutter pub get` again
- Delete `build` folder and rebuild

**App doesn't run on target Windows machine**

- Ensure all files from Release folder are copied
- Install Visual C++ Redistributable if needed
- Check Windows Defender isn't blocking the app

### Audio Issues on Windows:

If audio doesn't play:

- Check Windows audio permissions
- Verify MP3 file is accessible
- Try different MP3 file formats

---

## Quick Build Commands

**On macOS:**

```bash
# Build release
flutter build macos --release

# Run debug version
flutter run -d macos
```

**On Windows:**

```cmd
# Build release
flutter build windows --release

# Run debug version
flutter run -d windows

# Create MSIX package
dart run msix:create
```

---

For any issues, check the Flutter documentation:

- Windows: https://docs.flutter.dev/platform-integration/windows/building
- macOS: https://docs.flutter.dev/platform-integration/macos/building
