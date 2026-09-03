#pragma once
#include "peripherals/IPeripheral.h"
#include "board/BoardConfig.h"

class ButtonPeripheral final : public IPeripheral {
public:
    explicit ButtonPeripheral(ButtonBinding binding) : binding_(binding) {}

    bool Initialize(SDL_Renderer* renderer, TextureCache& textures,
                    const std::filesystem::path& assetDir) override;
    void OnBackendConnected(MonitorClient& monitor) override;
    void OnReset(MonitorClient& monitor) override;
    void HandleEvent(const SDL_Event& event, MonitorClient* monitor) override;
    void Render(SDL_Renderer* renderer) override;

private:
    void SetPressed(bool pressed, MonitorClient* monitor);
    bool Hit(int x, int y) const;

    ButtonBinding binding_;
    SDL_Texture* upTexture_ = nullptr;
    SDL_Texture* downTexture_ = nullptr;
    bool pressed_ = false;
};
