#include "peripherals/ButtonPeripheral.h"
#include "backend/MonitorClient.h"
#include "ui/TextureCache.h"
#include <string>

bool ButtonPeripheral::Initialize(SDL_Renderer*, TextureCache& textures,
                                  const std::filesystem::path& assetDir)
{
    upTexture_ = textures.LoadBmp(assetDir / "button_up.bmp");
    downTexture_ = textures.LoadBmp(assetDir / "button_down.bmp");
    return upTexture_ && downTexture_;
}

bool ButtonPeripheral::Hit(int x, int y) const
{
    return x >= binding_.x && x < binding_.x + binding_.w &&
           y >= binding_.y && y < binding_.y + binding_.h;
}

void ButtonPeripheral::SetPressed(bool pressed, MonitorClient* monitor)
{
    if(pressed_ == pressed && monitor == nullptr) return;
    pressed_ = pressed;
    if(!monitor || !monitor->IsConnected()) return;

    // teaching_board.repl uses invert:true; Press therefore drives MCU pin LOW.
    const std::string cmd = std::string(binding_.monitorObject) +
                            (pressed ? " Press" : " Release");
    monitor->Execute(cmd);
}

void ButtonPeripheral::OnBackendConnected(MonitorClient& monitor)
{
    SetPressed(false, &monitor);
}

void ButtonPeripheral::OnReset(MonitorClient& monitor)
{
    SetPressed(false, &monitor);
}

void ButtonPeripheral::HandleEvent(const SDL_Event& event, MonitorClient* monitor)
{
    if(event.type == SDL_MOUSEBUTTONDOWN &&
       Hit(event.button.x, event.button.y)) {
        SetPressed(true, monitor);
    }
    if(event.type == SDL_MOUSEBUTTONUP && pressed_) {
        SetPressed(false, monitor);
    }
}

void ButtonPeripheral::Render(SDL_Renderer* renderer)
{
    SDL_Rect rect{binding_.x, binding_.y, binding_.w, binding_.h};
    SDL_RenderCopy(renderer, pressed_ ? downTexture_ : upTexture_, nullptr, &rect);
}
