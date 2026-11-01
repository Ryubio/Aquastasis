@echo off
title Aquastasis - Mediterranean Ecosystem Defense
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ============================================================
echo         AQUASTASIS - COP31 ANTALYA ECOSYSTEM DEFENSE
echo ============================================================
echo.

:: 1. Check if a valid Aquastasis.exe exists in the current directory (> 1MB)
if exist "%~dp0Aquastasis.exe" (
    for %%F in ("%~dp0Aquastasis.exe") do (
        if %%~zF GTR 1000000 (
            echo [OK] Yerel Aquastasis calistiricisi bulundu.
            echo Aquastasis baslatiliyor...
            start "" "%~dp0Aquastasis.exe" --path "%~dp0."
            exit /b 0
        )
    )
)

:: 2. Check if local godot.exe exists (> 1MB)
if exist "%~dp0godot.exe" (
    for %%F in ("%~dp0godot.exe") do (
        if %%~zF GTR 1000000 (
            echo [OK] Yerel motor bulundu.
            echo Aquastasis baslatiliyor...
            start "" "%~dp0godot.exe" --path "%~dp0."
            exit /b 0
        )
    )
)

:: 3. Check if Godot is available in system PATH
where godot >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [OK] Sistemde kurulu Godot bulundu.
    echo Aquastasis baslatiliyor...
    start "" godot --path "%~dp0."
    exit /b 0
)

:: 4. Check common parent/desktop directories
for %%I in ("%~dp0..") do set "PARENT_DIR=%%~fI"
if exist "%PARENT_DIR%\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" (
    echo [OK] Ust klasorde Godot bulundu.
    start "" "%PARENT_DIR%\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --path "%~dp0."
    exit /b 0
)

for %%I in ("%~dp0..\..") do set "DESKTOP_DIR=%%~fI"
if exist "%DESKTOP_DIR%\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" (
    echo [OK] Masaustunde Godot bulundu.
    start "" "%DESKTOP_DIR%\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --path "%~dp0."
    exit /b 0
)

:: 5. Zero-Install Fallback: Automatically download portable Godot runner (No installation needed)
echo [BILGI] Bilgisayarinizda Godot Engine yuklu degil.
echo Oyunu calistirmak icin gerekli tek seferlik motor modulu indiriliyor...
echo Lutfen bekleyin (bu islem yalnizca ilk acilista 1 kez yapilir)...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $url = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip'; $zip = Join-Path $pwd 'godot_temp.zip'; Write-Host 'Motor indiriliyor...'; Invoke-WebRequest -Uri $url -OutFile $zip; Write-Host 'Arsiv aciliyor...'; Expand-Archive -Path $zip -DestinationPath $pwd -Force; Remove-Item $zip; Get-ChildItem -Filter 'Godot_v4*.exe' | Rename-Item -NewName 'Aquastasis.exe'; Write-Host 'Hazir!'"

if exist "%~dp0Aquastasis.exe" (
    for %%F in ("%~dp0Aquastasis.exe") do (
        if %%~zF GTR 1000000 (
            echo.
            echo ============================================================
            echo [BASARILI] Aquastasis.exe hazirlandi!
            echo Oyun baslatiliyor... Bundan sonra dogrudan Aquastasis.exe'ye
            echo veya bu dosyaya tiklayarak oyunu aninda acabilirsiniz.
            echo ============================================================
            start "" "%~dp0Aquastasis.exe" --path "%~dp0."
            exit /b 0
        )
    )
)

echo.
echo ============================================================
echo [HATA] Otomatik indirme basarisiz oldu.
echo Lutfen internet baglantinizi kontrol edin veya
echo https://godotengine.org/download adresinden Godot 4'u indirin.
echo ============================================================
echo.
pause
exit /b 1
