#pragma once

#include "peripherals/IPeripheral.h"
#include "board/BoardConfig.h"

class IGpioBackend;

class LedPeripheral final : public IPeripheral {
public:
    LedPeripheral(LedBinding binding, IGpioBackend* gpioBackend)
        : binding_(binding), gpioBackend_(gpioBackend) {}

    bool Initialize(SDL_Renderer* renderer, TextureCache& textures,
                    const std::filesystem::path& assetDir) override;
    void Poll(MonitorClient* monitor, uint32_t nowMs) override;
    void Render(SDL_Renderer* renderer) override;

private:
    LedBinding binding_;
    IGpioBackend* gpioBackend_ = nullptr;
    SDL_Texture* onTexture_ = nullptr;
    SDL_Texture* offTexture_ = nullptr;
    bool on_ = false;
};
