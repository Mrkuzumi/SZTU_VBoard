#pragma once
#include <SDL.h>
#include <filesystem>

class MonitorClient;
class TextureCache;

// Every visible/interactive board module implements this interface.
// Adding a new peripheral should normally require a new class plus one
// registration in TeachingBoard::BuildDefaultPeripherals().
class IPeripheral {
public:
    virtual ~IPeripheral() = default;

    virtual bool Initialize(SDL_Renderer* renderer,
                            TextureCache& textures,
                            const std::filesystem::path& assetDir) = 0;
    virtual void OnBackendConnected(MonitorClient& monitor) { (void)monitor; }
    virtual void OnReset(MonitorClient& monitor) { (void)monitor; }
    virtual void HandleEvent(const SDL_Event& event, MonitorClient* monitor) {
        (void)event; (void)monitor;
    }
    virtual void Poll(MonitorClient* monitor, uint32_t nowMs) {
        (void)monitor; (void)nowMs;
    }
    virtual void Render(SDL_Renderer* renderer) = 0;
};
