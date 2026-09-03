# Development workflow

## Primary OS

Use Windows 10/11 x64 for main development and release validation.

Reason: the product must be tested end-to-end with both STM32CubeIDE and Keil5, and Keil5 is a Windows workflow. Renode and SDL2 are cross-platform, so Linux support can be added after the Windows product path is stable.

## Windows toolchain

Preferred stack:

- MSVC x64 from Visual Studio / Build Tools
- CMake
- SDL2 fetched by CMake
- Renode portable under `third_party/renode`

The scripts currently accept these CMake generators, in order:

1. `Visual Studio 18 2026`
2. `Visual Studio 17 2022`

Run the environment check first:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\doctor.ps1
```

Then:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup_all.ps1
```

## Script-first maintenance rule

Bug fixes and feature additions should be reproducible.

For a change that existing users/checkouts need, add an idempotent PowerShell patch to:

```text
tools/patches/NNN_description.ps1
```

A patch should:

- detect the project root itself;
- back up files before destructive replacement when appropriate;
- be safe to rerun where practical;
- print exactly what it changed;
- fail fast on missing prerequisites;
- avoid asking the user to manually edit many source files.

Large feature versions can still be delivered as a full ZIP, but the important migration/fix should also have a script when feasible.

## Peripheral extension checklist

When adding an external module such as buzzer/UART/SPI display:

1. Add a new `IPeripheral` implementation.
2. Keep rendering/input/backend state inside that peripheral class.
3. Add only board composition wiring to `TeachingBoard`.
4. Put Renode-specific hardware modeling under `renode/`.
5. Keep MCU pin mapping in board configuration, not scattered through UI code.
6. Add a HAL example or test firmware snippet.
7. Add a patch script if the feature changes an existing checkout.
