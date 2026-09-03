#pragma once
#include <array>
#include <string>

struct LedBinding {
    const char* label;
    const char* monitorObject;
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

    static constexpr std::array<LedBinding, 4> LEDs{{
        {"LED0 / PC13", "gpioPortC.led0", true, 188, 238},
        {"LED1 / PA0",  "gpioPortA.led1", false, 188, 320},
        {"LED2 / PA1",  "gpioPortA.led2", false, 188, 402},
        {"LED3 / PA2",  "gpioPortA.led3", false, 188, 484},
    }};

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
