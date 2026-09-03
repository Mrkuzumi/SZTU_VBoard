#pragma once

#include "backend/gpio/IGpioBackend.h"
#include <array>
#include <atomic>
#include <cstdint>
#include <string>
#include <thread>

class RenodeExternalControl final : public IGpioBackend {
public:
    RenodeExternalControl();
    ~RenodeExternalControl() override;

    RenodeExternalControl(const RenodeExternalControl&) = delete;
    RenodeExternalControl& operator=(const RenodeExternalControl&) = delete;

    // Starts a reconnecting worker thread. This returns immediately.
    void Start(std::string host, std::uint16_t port, std::string machineName);
    void Stop();

    bool IsConnected() const noexcept override;
    bool TryRead(const char* controller,
                 int pin,
                 bool& state) const noexcept override;

private:
    void WorkerMain();

    std::string host_ = "127.0.0.1";
    std::string machineName_ = "vstm32";
    std::uint16_t port_ = 33334;

    std::atomic<bool> stopRequested_{false};
    std::atomic<bool> connected_{false};
    std::array<std::atomic<bool>, 4> gpioBMirrorStates_{};

    std::thread worker_;
};
