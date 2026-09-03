#include "peripherals/ButtonPeripheral.h"

#include "backend/gpio/IGpioBackend.h"
#include "ui/TextureCache.h"

bool ButtonPeripheral::Initialize(
    SDL_Renderer*,
    TextureCache& textures,
    const std::filesystem::path& assetDir)
{
    upTexture_ =
        textures.LoadBmp(
            assetDir / "button_up.bmp"
        );

    downTexture_ =
        textures.LoadBmp(
            assetDir / "button_down.bmp"
        );

    pressed_ = false;

    // Active-low physical push buttons:
    // released => HIGH.
    if(gpioBackend_) {
        const bool releasedLevel =
            binding_.activeLow ? true : false;

        gpioBackend_->QueueWrite(
            binding_.controller,
            binding_.pin,
            releasedLevel
        );
    }

    return upTexture_ && downTexture_;
}

bool ButtonPeripheral::Hit(int x, int y) const
{
    return
        x >= binding_.x &&
        x < binding_.x + binding_.w &&
        y >= binding_.y &&
        y < binding_.y + binding_.h;
}

void ButtonPeripheral::SetPressed(bool pressed)
{
    if(pressed_ == pressed) return;

    pressed_ = pressed;

    if(!gpioBackend_) return;

    // activeLow:
    // pressed  => LOW
    // released => HIGH
    const bool electricalLevel =
        binding_.activeLow
            ? !pressed
            : pressed;

    gpioBackend_->QueueWrite(
        binding_.controller,
        binding_.pin,
        electricalLevel
    );
}

void ButtonPeripheral::HandleEvent(
    const SDL_Event& event,
    MonitorClient*)
{
    if(event.type == SDL_MOUSEBUTTONDOWN &&
       event.button.button == SDL_BUTTON_LEFT &&
       Hit(
           event.button.x,
           event.button.y
       )) {
        SetPressed(true);
        return;
    }

    // Release the button even if the mouse was moved outside the hitbox.
    if(event.type == SDL_MOUSEBUTTONUP &&
       event.button.button == SDL_BUTTON_LEFT &&
       pressed_) {
        SetPressed(false);
    }
}

void ButtonPeripheral::Render(
    SDL_Renderer* renderer)
{
    SDL_Rect rect{
        binding_.x,
        binding_.y,
        binding_.w,
        binding_.h
    };

    SDL_RenderCopy(
        renderer,
        pressed_
            ? downTexture_
            : upTexture_,
        nullptr,
        &rect
    );
}
