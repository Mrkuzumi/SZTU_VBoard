#pragma once

#include <array>
#include <cstdint>

class IOledBackend;

class OledFramebuffer {
public:
    explicit OledFramebuffer(IOledBackend* backend = nullptr);

    void SetBackend(IOledBackend* backend) noexcept;
    bool Poll();

    const std::array<std::uint8_t, 1024>& Data() const noexcept
    {
        return data_;
    }

    bool DisplayOn() const noexcept { return displayOn_; }
    bool Inverse() const noexcept { return inverse_; }
    bool AllOn() const noexcept { return allOn_; }

private:
    IOledBackend* backend_ = nullptr;

    std::array<std::uint8_t, 1024> data_{};
    std::uint32_t generation_ = 0;

    bool displayOn_ = false;
    bool inverse_ = false;
    bool allOn_ = false;
};
