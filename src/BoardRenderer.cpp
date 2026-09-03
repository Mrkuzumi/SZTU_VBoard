#include "BoardRenderer.h"
#include "BoardConfig.h"
#include <vector>

BoardRenderer::~BoardRenderer() { Destroy(); }

SDL_Texture* BoardRenderer::LoadBmp(const std::filesystem::path& p)
{
    SDL_Surface* s = SDL_LoadBMP(p.u8string().c_str());
    if(!s) return nullptr;
    SDL_Texture* t = SDL_CreateTextureFromSurface(renderer_, s);
    SDL_FreeSurface(s);
    return t;
}

bool BoardRenderer::Initialize(SDL_Renderer* renderer, const std::filesystem::path& assetDir)
{
    renderer_ = renderer;
    board_ = LoadBmp(assetDir / "board.bmp");
    ledOn_ = LoadBmp(assetDir / "led_on.bmp");
    ledOff_ = LoadBmp(assetDir / "led_off.bmp");
    buttonUp_ = LoadBmp(assetDir / "button_up.bmp");
    buttonDown_ = LoadBmp(assetDir / "button_down.bmp");
    oledModule_ = LoadBmp(assetDir / "oled_module.bmp");
    oledPixels_ = SDL_CreateTexture(renderer_, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, 128, 64);
    if(oledPixels_) SDL_SetTextureScaleMode(oledPixels_, SDL_ScaleModeNearest);
    return board_ && ledOn_ && ledOff_ && buttonUp_ && buttonDown_ && oledModule_ && oledPixels_;
}

void BoardRenderer::Shutdown()
{
    Destroy();
    renderer_ = nullptr;
}

void BoardRenderer::Destroy()
{
    for(SDL_Texture* t : {board_, ledOn_, ledOff_, buttonUp_, buttonDown_, oledModule_, oledPixels_}) {
        if(t) SDL_DestroyTexture(t);
    }
    board_ = ledOn_ = ledOff_ = buttonUp_ = buttonDown_ = oledModule_ = oledPixels_ = nullptr;
}

void BoardRenderer::UpdateOledTexture(const std::array<uint8_t,1024>& oled)
{
    uint32_t* pixels = nullptr;
    int pitch = 0;
    if(SDL_LockTexture(oledPixels_, nullptr, reinterpret_cast<void**>(&pixels), &pitch) != 0) return;
    const int stride = pitch / 4;
    for(int y = 0; y < 64; ++y) {
        for(int x = 0; x < 128; ++x) {
            const int page = y / 8;
            const int bit = y % 8;
            const bool on = (oled[page * 128 + x] >> bit) & 0x1;
            pixels[y * stride + x] = on ? 0xFFBDF7FFu : 0xFF06171Cu;
        }
    }
    SDL_UnlockTexture(oledPixels_);
}

void BoardRenderer::Render(const std::array<bool,4>& ledOn,
                           const std::array<bool,4>& buttonPressed,
                           const std::array<uint8_t,1024>& oled,
                           bool renodeConnected,
                           bool paused)
{
    SDL_SetRenderDrawColor(renderer_, 16, 19, 24, 255);
    SDL_RenderClear(renderer_);
    SDL_Rect full{0,0,BoardConfig::WindowWidth,BoardConfig::WindowHeight};
    SDL_RenderCopy(renderer_, board_, nullptr, &full);

    for(size_t i = 0; i < BoardConfig::LEDs.size(); ++i) {
        auto& b = BoardConfig::LEDs[i];
        SDL_Rect r{b.x, b.y, 48, 48};
        SDL_RenderCopy(renderer_, ledOn[i] ? ledOn_ : ledOff_, nullptr, &r);
    }

    for(size_t i = 0; i < BoardConfig::Buttons.size(); ++i) {
        auto& b = BoardConfig::Buttons[i];
        SDL_Rect r{b.x,b.y,b.w,b.h};
        SDL_RenderCopy(renderer_, buttonPressed[i] ? buttonDown_ : buttonUp_, nullptr, &r);
    }

    SDL_Rect om{BoardConfig::OledX, BoardConfig::OledY, BoardConfig::OledW, BoardConfig::OledH};
    SDL_RenderCopy(renderer_, oledModule_, nullptr, &om);
    UpdateOledTexture(oled);
    SDL_Rect scr{BoardConfig::OledScreenX, BoardConfig::OledScreenY, BoardConfig::OledScreenW, BoardConfig::OledScreenH};
    SDL_RenderCopy(renderer_, oledPixels_, nullptr, &scr);

    // top-right status lamps, drawn over labels baked into board.bmp
    SDL_Rect status{1079, 35, 18, 18};
    if(renodeConnected) SDL_SetRenderDrawColor(renderer_, 77, 223, 122, 255);
    else SDL_SetRenderDrawColor(renderer_, 232, 88, 88, 255);
    SDL_RenderFillRect(renderer_, &status);
    SDL_Rect run{1130,35,18,18};
    if(paused) SDL_SetRenderDrawColor(renderer_, 245, 183, 66, 255);
    else SDL_SetRenderDrawColor(renderer_, 77, 223, 122, 255);
    SDL_RenderFillRect(renderer_, &run);

    SDL_RenderPresent(renderer_);
}
