# Changelog

## 0.1.1

- Fixed Windows CMake generator bug where `-A x64` could be combined with `NMake Makefiles`.
- Added `tools/doctor.ps1` and shared `tools/lib/Toolchain.ps1`.
- Auto-detects installed MSVC toolchains and prefers VS 2026, then VS 2022.
- Automatically removes stale CMake build cache when the generator changes.
- Refactored source into `app/`, `backend/`, `board/`, `peripherals/`, `ui/` modules.
- Added `IPeripheral` lifecycle interface and modular LED/Button/SSD1306 implementations.
- Added script-first maintenance rules and the first migration patch under `tools/patches/`.

## 0.1.0

- Initial STM32F103C8T6 virtual teaching board MVP.

## Patch 003 - Renode Telnet Monitor
- Fixed the Renode -P backend client to perform Telnet IAC negotiation before Monitor commands.
- Added a Telnet-aware runtime probe.


## Patch 005 - Non-blocking GPIO bridge
- Removed synchronous Renode Monitor polling from the SDL/render thread.
- Added an event-driven Renode GPIO-to-host bridge for LED0..LED3.
- Started the GDB server directly from the runtime script.
- Added 	ools/check_led_bridge.ps1.
- Button backend input is temporarily deferred to the External Control API migration.

## Patch 021 - External Control LED backend
- Replaced temporary LED state files with a Windows-native Renode External Control backend.
- External Control traffic runs on a dedicated worker thread; SDL performs no network I/O.
- Mirrored PC13/PA0/PA1/PA2 to hidden PB0/PB1/PB2/PB3 observation pins.
- Preserved the proven relative @firmware.elf Windows loading fix.
- Added External Control server on TCP 33334 and retained GDB on 3333.
- Overrode STM32F103 SysTick to the current HSI 8 MHz board preset so HAL_Delay timing is realistic.

## Patch 022 - External Control button input
- Added asynchronous GPIO SET_STATE support to the Windows-native External Control backend.
- KEY0..KEY3 now inject PB12..PB15 electrical levels into Renode.
- Buttons are active-low: released=HIGH, pressed=LOW.
- SDL input events only update atomics; socket I/O remains on the backend worker thread.
- LED output observation from Patch 021 remains unchanged.
