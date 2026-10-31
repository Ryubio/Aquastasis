@echo off
title Pulse of the Mediterranean
setlocal
cd /d "%~dp0"

for %%I in ("%~dp0.") do set "PROJ_DIR=%%~fI"
for %%I in ("%~dp0..") do set "DESKTOP_DIR=%%~fI"

set "GODOT_EXE=%DESKTOP_DIR%\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"

if not exist "%GODOT_EXE%" (
    where godot >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        set "GODOT_EXE=godot"
    )
)

if not exist "%GODOT_EXE%" (
    echo ============================================================
    echo [HATA] Godot calistirilabilir dosyasi bulunamadi!
    echo Aranan yol: "%GODOT_EXE%"
    echo ============================================================
    echo.
    pause
    exit /b 1
)

echo Pulse of the Mediterranean baslatiliyor...
echo.

"%GODOT_EXE%" --path "%PROJ_DIR%"

if %ERRORLEVEL% neq 0 (
    echo.
    echo ============================================================
    echo Oyun beklenmedik sekilde kapandi. Hata kodu: %ERRORLEVEL%
    echo ============================================================
    pause
)
