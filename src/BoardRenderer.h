#pragma once
#include <SDL.h>
#include <array>
#include <filesystem>
#include <cstdint>

class BoardRenderer {
public:
    ~BoardRenderer();
    bool Initialize(SDL_Renderer* renderer, const std::filesystem::path& assetDir);
    void Shutdown();
    void Render(const std::array<bool,4>& ledOn,
                const std::array<bool,4>& buttonPressed,
                const std::array<uint8_t,1024>& oled,
                bool renodeConnected,
                bool paused);

private:
    SDL_Texture* LoadBmp(const std::filesystem::path& p);
    void Destroy();
    void UpdateOledTexture(const std::array<uint8_t,1024>& oled);

    SDL_Renderer* renderer_ = nullptr;
    SDL_Texture* board_ = nullptr;
    SDL_Texture* ledOn_ = nullptr;
    SDL_Texture* ledOff_ = nullptr;
    SDL_Texture* buttonUp_ = nullptr;
    SDL_Texture* buttonDown_ = nullptr;
    SDL_Texture* oledModule_ = nullptr;
    SDL_Texture* oledPixels_ = nullptr;
};
