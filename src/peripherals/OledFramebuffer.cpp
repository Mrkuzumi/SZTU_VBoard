#include "peripherals/OledFramebuffer.h"

#include "backend/oled/IOledBackend.h"

OledFramebuffer::OledFramebuffer(IOledBackend* backend)
    : backend_(backend)
{
}

void OledFramebuffer::SetBackend(IOledBackend* backend) noexcept
{
    backend_ = backend;
}

bool OledFramebuffer::Poll()
{
    if(!backend_) {
        return false;
    }

    std::array<std::uint8_t, 1024> next{};
    std::uint32_t nextGeneration = generation_;
    bool nextDisplayOn = displayOn_;
    bool nextInverse = inverse_;
    bool nextAllOn = allOn_;

    if(!backend_->TryCopyOledFrame(
           next,
           nextGeneration,
           nextDisplayOn,
           nextInverse,
           nextAllOn)) {
        return false;
    }

    const bool changed =
        nextGeneration != generation_ ||
        nextDisplayOn != displayOn_ ||
        nextInverse != inverse_ ||
        nextAllOn != allOn_;

    data_ = next;
    generation_ = nextGeneration;
    displayOn_ = nextDisplayOn;
    inverse_ = nextInverse;
    allOn_ = nextAllOn;

    return changed;
}
