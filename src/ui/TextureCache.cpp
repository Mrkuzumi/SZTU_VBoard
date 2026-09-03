#include "ui/TextureCache.h"

TextureCache::~TextureCache() { Clear(); }

SDL_Texture* TextureCache::LoadBmp(const std::filesystem::path& path)
{
    const std::string key = std::filesystem::absolute(path).u8string();
    auto it = cache_.find(key);
    if(it != cache_.end()) return it->second;
    if(!renderer_) return nullptr;

    SDL_Surface* surface = SDL_LoadBMP(path.u8string().c_str());
    if(!surface) return nullptr;
    SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer_, surface);
    SDL_FreeSurface(surface);
    if(texture) cache_.emplace(key, texture);
    return texture;
}

void TextureCache::Clear()
{
    for(auto& [_, texture] : cache_) {
        if(texture) SDL_DestroyTexture(texture);
    }
    cache_.clear();
}
