@echo off
echo ====================================
echo  Athan Waterway - Windows Build
echo ====================================
echo.

echo [1/3] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo Error: Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo [2/3] Building Windows release...
call flutter build windows --release
if errorlevel 1 (
    echo Error: Build failed
    pause
    exit /b 1
)

echo.
echo [3/3] Build completed successfully!
echo.
echo The application is located at:
echo build\windows\x64\runner\Release\
echo.
echo You can now:
echo - Run athan_waterway.exe directly
echo - Create an installer using Inno Setup
echo - Distribute the entire Release folder
echo.
pause
