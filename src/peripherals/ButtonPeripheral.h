#pragma once

#include "peripherals/IPeripheral.h"
#include "board/BoardConfig.h"

class IGpioBackend;

class ButtonPeripheral final : public IPeripheral {
public:
    ButtonPeripheral(
        ButtonBinding binding,
        IGpioBackend* gpioBackend
    )
        : binding_(binding),
          gpioBackend_(gpioBackend)
    {
    }

    bool Initialize(
        SDL_Renderer* renderer,
        TextureCache& textures,
        const std::filesystem::path& assetDir
    ) override;

    void HandleEvent(
        const SDL_Event& event,
        MonitorClient* monitor
    ) override;

    void Render(SDL_Renderer* renderer) override;

private:
    void SetPressed(bool pressed);
    bool Hit(int x, int y) const;

    ButtonBinding binding_;
    IGpioBackend* gpioBackend_ = nullptr;

    SDL_Texture* upTexture_ = nullptr;
    SDL_Texture* downTexture_ = nullptr;

    bool pressed_ = false;
};
