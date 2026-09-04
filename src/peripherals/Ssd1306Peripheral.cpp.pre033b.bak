#include "peripherals/Ssd1306Peripheral.h"
#include "board/BoardConfig.h"
#include "ui/TextureCache.h"

Ssd1306Peripheral::~Ssd1306Peripheral()
{
    if(pixelTexture_) SDL_DestroyTexture(pixelTexture_);
}

bool Ssd1306Peripheral::Initialize(SDL_Renderer* renderer, TextureCache& textures,
                                   const std::filesystem::path& assetDir)
{
    moduleTexture_ = textures.LoadBmp(assetDir / "oled_module.bmp");
    pixelTexture_ = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                      SDL_TEXTUREACCESS_STREAMING, 128, 64);
    if(pixelTexture_) SDL_SetTextureScaleMode(pixelTexture_, SDL_ScaleModeNearest);
    return moduleTexture_ && pixelTexture_;
}

void Ssd1306Peripheral::Poll(MonitorClient*, uint32_t)
{
    framebuffer_.Poll();
}

void Ssd1306Peripheral::UpdateTexture()
{
    if(!pixelTexture_) return;
    uint32_t* pixels = nullptr;
    int pitch = 0;
    if(SDL_LockTexture(pixelTexture_, nullptr,
                       reinterpret_cast<void**>(&pixels), &pitch) != 0) return;

    const auto& oled = framebuffer_.Data();
    const int stride = pitch / 4;
    for(int y = 0; y < 64; ++y) {
        for(int x = 0; x < 128; ++x) {
            const int page = y / 8;
            const int bit = y % 8;
            const bool on = ((oled[page * 128 + x] >> bit) & 0x1) != 0;
            pixels[y * stride + x] = on ? 0xFFBDF7FFu : 0xFF06171Cu;
        }
    }
    SDL_UnlockTexture(pixelTexture_);
}

void Ssd1306Peripheral::Render(SDL_Renderer* renderer)
{
    SDL_Rect module{BoardConfig::OledX, BoardConfig::OledY,
                    BoardConfig::OledW, BoardConfig::OledH};
    SDL_RenderCopy(renderer, moduleTexture_, nullptr, &module);

    UpdateTexture();
    SDL_Rect screen{BoardConfig::OledScreenX, BoardConfig::OledScreenY,
                    BoardConfig::OledScreenW, BoardConfig::OledScreenH};
    SDL_RenderCopy(renderer, pixelTexture_, nullptr, &screen);
}
