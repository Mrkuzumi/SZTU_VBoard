# Architecture (V0.1.1)

```text
CubeIDE / Keil5
     |
     | build -> .elf / .axf
     v
 tools/ide_launch.cmd
     |
     v
VirtualSTM32.exe
     |
     +-- app/App                  application lifecycle only
     |
     +-- board/TeachingBoard     board composition / module registry
     |       |
     |       +-- IPeripheral
     |            +-- LedPeripheral
     |            +-- ButtonPeripheral
     |            +-- Ssd1306Peripheral
     |
     +-- backend/
     |       +-- RenodeProcess
     |       +-- MonitorClient
     |
     +-- ui/TextureCache
             |
             v
          SDL2 GUI

VirtualSTM32.exe <---- monitor TCP ----> Renode
                                      Cortex-M3 / NVIC / SysTick
                                      STM32F1 GPIO / I2C1
                                      |
                                      +-- LED observers
                                      +-- Button inputs
                                      +-- DummyI2CSlave 0x3C
                                               |
                                               +-- ssd1306_bridge.py
                                                   -> %TEMP%/VirtualSTM32/oled.bin
```

## Module rule

`App` is not allowed to know how an LED, button, OLED, UART or future peripheral works.
It only forwards lifecycle events to `TeachingBoard`.

Every user-visible board peripheral implements `IPeripheral`:

- `Initialize()` — load resources / create textures
- `OnBackendConnected()` — establish initial MCU-facing state
- `OnReset()` — reset module state
- `HandleEvent()` — mouse/keyboard input
- `Poll()` — read backend state or framebuffer
- `Render()` — draw itself

To add a new peripheral, prefer:

1. Create `src/peripherals/NewPeripheral.{h,cpp}`.
2. Implement `IPeripheral`.
3. Add its board binding/configuration.
4. Register it in `TeachingBoard::BuildDefaultPeripherals()`.
5. If Renode needs a device model, add it under `renode/`.
6. Add/update a scripted patch under `tools/patches/` for existing checkouts.

Do not put new peripheral-specific logic back into `App.cpp`.

## Build/tooling rule

Windows is the primary development and validation platform because Keil5 integration is a core feature.
Linux may later be used for CI/static checks and a future port.

The build scripts explicitly choose a Visual Studio CMake generator. They must not rely on the user's ambient `CMAKE_GENERATOR`, because an inherited `NMake Makefiles` value caused the V0.1.0 `-A x64` failure.

Before debugging a build environment, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\doctor.ps1
```
