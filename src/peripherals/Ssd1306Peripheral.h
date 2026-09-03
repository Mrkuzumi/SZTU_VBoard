#pragma once
#include "peripherals/IPeripheral.h"
#include "peripherals/OledFramebuffer.h"

class Ssd1306Peripheral final : public IPeripheral {
public:
    ~Ssd1306Peripheral() override;

    bool Initialize(SDL_Renderer* renderer, TextureCache& textures,
                    const std::filesystem::path& assetDir) override;
    void Poll(MonitorClient* monitor, uint32_t nowMs) override;
    void Render(SDL_Renderer* renderer) override;

private:
    void UpdateTexture();

    SDL_Texture* moduleTexture_ = nullptr;
    SDL_Texture* pixelTexture_ = nullptr;
    OledFramebuffer framebuffer_;
};
