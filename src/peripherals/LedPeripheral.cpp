#include "peripherals/LedPeripheral.h"
#include "backend/gpio/IGpioBackend.h"
#include "ui/TextureCache.h"

bool LedPeripheral::Initialize(SDL_Renderer*,
                               TextureCache& textures,
                               const std::filesystem::path& assetDir)
{
    onTexture_ = textures.LoadBmp(assetDir / "led_on.bmp");
    offTexture_ = textures.LoadBmp(assetDir / "led_off.bmp");
    return onTexture_ && offTexture_;
}

void LedPeripheral::Poll(MonitorClient*, uint32_t)
{
    if(!gpioBackend_) return;

    bool raw = false;
    if(!gpioBackend_->TryRead(binding_.observerController,
                              binding_.observerPin,
                              raw)) {
        return;
    }

    on_ = binding_.activeLow ? !raw : raw;
}

void LedPeripheral::Render(SDL_Renderer* renderer)
{
    SDL_Rect rect{binding_.x, binding_.y, 48, 48};
    SDL_RenderCopy(renderer, on_ ? onTexture_ : offTexture_, nullptr, &rect);
}
