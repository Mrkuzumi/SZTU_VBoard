#pragma once

// Backend-neutral GPIO interface used by visible/interactive board peripherals.
//
// All methods called from the SDL thread MUST be non-blocking.
// Renode network I/O is performed by the backend worker thread.
class IGpioBackend {
public:
    virtual ~IGpioBackend() = default;

    virtual bool IsConnected() const noexcept = 0;

    // Non-blocking cached input/state read.
    virtual bool TryRead(const char* controller,
                         int pin,
                         bool& state) const noexcept = 0;

    // Non-blocking queued GPIO injection.
    //
    // This only changes a desired-state cache. The backend worker sends the
    // actual Renode External Control SET_STATE command asynchronously.
    virtual bool QueueWrite(const char* controller,
                            int pin,
                            bool state) noexcept = 0;
};
