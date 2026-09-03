#pragma once
#include <array>
#include <cstdint>

struct LedBinding {
    const char* label;

    // Renode output is internally mirrored into gpioPortB pins 0..3.
    // External Control reads the sink/input side, which correctly reflects
    // the actual output line from PC13/PA0/PA1/PA2.
    const char* observerController;
    int observerPin;

    bool activeLow;
    int x, y;
};

struct ButtonBinding {
    const char* label;
    const char* monitorObject;
    int x, y, w, h;
};

struct BoardConfig {
    static constexpr int WindowWidth = 1200;
    static constexpr int WindowHeight = 760;

    static constexpr int MonitorPort = 33335;
    static constexpr int GdbPort = 3333;
    static constexpr int ExternalControlPort = 33334;

    // Current STM32 test preset uses HSI directly (8 MHz).
    //
    // Renode 1.16.1's stock stm32f103.repl fixes NVIC SysTick at 72 MHz,
    // which makes HAL_Delay() ~9x too fast for an 8 MHz firmware clock.
    // Patch 021 overrides SysTick to this board preset value.
    //
    // Later this becomes a clock-profile/auto-detection setting.
    static constexpr std::uint32_t SysTickFrequencyHz = 8000000;

    static constexpr std::array<LedBinding, 4> LEDs{{
        {"LED0 / PC13", "gpioPortB", 0, true,  188, 238},
        {"LED1 / PA0",  "gpioPortB", 1, false, 188, 320},
        {"LED2 / PA1",  "gpioPortB", 2, false, 188, 402},
        {"LED3 / PA2",  "gpioPortB", 3, false, 188, 484},
    }};

    // Buttons remain GUI-local in Patch 021. They will use External Control
    // GPIO SET_STATE in the next input patch.
    static constexpr std::array<ButtonBinding, 4> Buttons{{
        {"KEY0 / PB12", "gpioPortB.key0", 470, 604, 120, 58},
        {"KEY1 / PB13", "gpioPortB.key1", 615, 604, 120, 58},
        {"KEY2 / PB14", "gpioPortB.key2", 760, 604, 120, 58},
        {"KEY3 / PB15", "gpioPortB.key3", 905, 604, 120, 58},
    }};

    static constexpr int OledX = 605;
    static constexpr int OledY = 165;
    static constexpr int OledW = 472;
    static constexpr int OledH = 310;
    static constexpr int OledScreenX = 642;
    static constexpr int OledScreenY = 215;
    static constexpr int OledScreenW = 384;
    static constexpr int OledScreenH = 192;
};
