#pragma once
#include <SDL.h>
#include <filesystem>
#include <string>
#include <unordered_map>

class TextureCache {
public:
    explicit TextureCache(SDL_Renderer* renderer = nullptr) : renderer_(renderer) {}
    ~TextureCache();

    TextureCache(const TextureCache&) = delete;
    TextureCache& operator=(const TextureCache&) = delete;

    void SetRenderer(SDL_Renderer* renderer) { renderer_ = renderer; }
    SDL_Texture* LoadBmp(const std::filesystem::path& path);
    void Clear();

private:
    SDL_Renderer* renderer_ = nullptr;
    std::unordered_map<std::string, SDL_Texture*> cache_;
};
