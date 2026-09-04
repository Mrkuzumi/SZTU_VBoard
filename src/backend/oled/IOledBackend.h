#pragma once

#include <array>
#include <cstdint>

class IOledBackend {
public:
    virtual ~IOledBackend() = default;

    // Non-blocking copy from the External Control worker's cache.
    virtual bool TryCopyOledFrame(
        std::array<std::uint8_t, 1024>& frame,
        std::uint32_t& generation,
        bool& displayOn,
        bool& inverse,
        bool& allOn) const noexcept = 0;
};
