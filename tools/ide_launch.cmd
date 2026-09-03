@echo off
setlocal EnableExtensions EnableDelayedExpansion
if "%~1"=="" (
  echo Usage: ide_launch.cmd firmware.elf_or_axf
  exit /b 2
)

set "ARG=%~1"
set "ELF=%~f1"
set "ROOT=%~dp0.."
set "EXE=%ROOT%\build\Release\VirtualSTM32.exe"
if not exist "%EXE%" set "EXE=%ROOT%\build\VirtualSTM32.exe"
if not exist "%EXE%" (
  echo [VirtualSTM32] VirtualSTM32.exe not found. Run tools\build_windows.ps1 first.
  exit /b 3
)

rem Some IDE setups may pass only the linker output file name. If the path supplied by
rem the IDE is not directly valid, search below the IDE's current project directory.
if not exist "%ELF%" (
  set "FOUND="
  for /r "%CD%" %%F in ("%ARG%") do (
    if exist "%%~fF" if not defined FOUND set "FOUND=%%~fF"
  )
  if defined FOUND set "ELF=!FOUND!"
)

if not exist "%ELF%" (
  echo [VirtualSTM32] Firmware not found: %ARG%
  echo [VirtualSTM32] Current directory: %CD%
  exit /b 4
)

rem Replace the previous virtual board, mimicking re-programming the same physical board.
taskkill /IM VirtualSTM32.exe /T /F >nul 2>nul
start "VirtualSTM32" "%EXE%" --elf "%ELF%"
exit /b 0
