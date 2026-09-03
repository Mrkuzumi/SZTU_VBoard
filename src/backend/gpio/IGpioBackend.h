#pragma once

// Backend-neutral GPIO view used by visible board peripherals.
//
// IMPORTANT:
// On STM32F1/Renode, reading a source GPIO through External Control returns
// input-side state. Output LEDs therefore observe dedicated mirror/sink pins
// created by RenodeProcess. This interface deliberately hides that detail
// from LedPeripheral.
class IGpioBackend {
public:
    virtual ~IGpioBackend() = default;

    virtual bool IsConnected() const noexcept = 0;

    // Non-blocking cached read. This function must never perform network I/O
    // on the SDL/render thread.
    virtual bool TryRead(const char* controller,
                         int pin,
                         bool& state) const noexcept = 0;
};
