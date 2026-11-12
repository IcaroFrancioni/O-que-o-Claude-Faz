@echo off
rem Exporta o Returing para todos os alvos possiveis no Windows e pula (com aviso) os que nao podem ser gerados aqui.
rem   exportar.bat                  modo debug, todos os alvos possiveis
rem   exportar.bat release          modo release
rem   exportar.bat debug windows linux android    so os alvos pedidos
rem Alvos: windows linux linux-arm64 macos android aab web   (iOS so exporta em macOS com Xcode: veja entrega/EXPORTAR.md)
rem Defina GODOT=C:\caminho\Godot_v4.7.2-stable_win64_console.exe se o godot nao estiver no PATH.
setlocal EnableDelayedExpansion
cd /d "%~dp0"
set MODO=debug
if /I "%~1"=="debug" ( set MODO=debug & shift )
if /I "%~1"=="release" ( set MODO=release & shift )
set ALVOS=%1 %2 %3 %4 %5 %6 %7 %8
if "%~1"=="" set ALVOS=windows linux linux-arm64 macos android aab web ios

if "%GODOT%"=="" (
  where godot >nul 2>nul && ( for /f "delims=" %%G in ('where godot') do set GODOT=%%G )
)
if "%GODOT%"=="" (
  echo ERRO: Godot nao encontrado. Instale o Godot 4.7.x ou defina GODOT=caminho\do\godot.exe
  exit /b 2
)
for /f "tokens=1-4 delims=." %%a in ('"%GODOT%" --version') do set VERSAO=%%a.%%b.%%c.%%d
set VERSAO=%VERSAO:.official=%
echo Godot: %GODOT% (%VERSAO%) ^| modo: %MODO%

set TEMPLATES=1
if not exist "%APPDATA%\Godot\export_templates\%VERSAO%" (
  set TEMPLATES=0
  echo AVISO: templates de exportacao %VERSAO% nao instalados em "%APPDATA%\Godot\export_templates\%VERSAO%".
  echo        Instale em Editor ^> Gerenciar templates de exportacao ^(veja entrega/EXPORTAR.md^).
)

"%GODOT%" --headless --path . --import >nul 2>nul
if not exist build mkdir build
set FALHOU=0
set FLAG=--export-debug
if "%MODO%"=="release" set FLAG=--export-release

for %%A in (%ALVOS%) do (
  if "!TEMPLATES!"=="0" (
    echo PULADO   %%A: sem templates de exportacao
  ) else if /I "%%A"=="windows" ( call :exportar windows "Windows (PC)" build\windows\Returing.exe
  ) else if /I "%%A"=="linux" ( call :exportar linux "Linux (PC, x86_64)" build\linux\Returing.x86_64
  ) else if /I "%%A"=="linux-arm64" ( call :exportar linux-arm64 "Linux (PC, arm64)" build\linux-arm64\Returing.arm64
  ) else if /I "%%A"=="macos" (
    call :exportar macos "macOS (PC, universal)" build\macos\Returing.zip
    echo PULADO   macos ^(assinatura/notarizacao^): so em um Mac - o .zip gerado NAO esta assinado
  ) else if /I "%%A"=="web" ( call :exportar web "Web (iPhone, Android e navegador)" build\web\index.html
  ) else if /I "%%A"=="android" (
    if "%ANDROID_HOME%"=="" ( echo PULADO   android: Android SDK nao encontrado ^(defina ANDROID_HOME^) ) else (
      where java >nul 2>nul && ( call :exportar android "Android (APK, arm64)" build\android\Returing.apk ) || echo PULADO   android: JDK 17 nao encontrado
    )
  ) else if /I "%%A"=="aab" (
    if "%ANDROID_HOME%"=="" ( echo PULADO   aab: Android SDK nao encontrado ) else if not exist android\build ( echo PULADO   aab: instale o modelo de compilacao Android ^(veja entrega/EXPORTAR.md^) ) else (
      call :exportar aab "Android (AAB, arm64)" build\android\Returing.aab
    )
  ) else if /I "%%A"=="ios" ( echo PULADO   ios: so exporta em macOS com Xcode ^(veja entrega/EXPORTAR.md^)
  ) else ( echo PULADO   %%A: alvo desconhecido )
)
if "%FALHOU%"=="1" exit /b 1
exit /b 0

:exportar
set ALVO=%~1
set PRESET=%~2
set SAIDA=%~3
for %%D in ("%SAIDA%") do if not exist "%%~dpD" mkdir "%%~dpD"
echo ^>^>^> exportando %ALVO%: %PRESET% -^> %SAIDA%
"%GODOT%" --headless --path . %FLAG% "%PRESET%" "%SAIDA%" > build\log_%ALVO%.txt 2>&1
if exist "%SAIDA%" ( echo OK       %ALVO% ^(%SAIDA%^) ) else ( echo FALHOU   %ALVO% ^(veja build\log_%ALVO%.txt^) & set FALHOU=1 )
goto :eof
